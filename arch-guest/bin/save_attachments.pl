use strict;
use warnings;

use DB_File;
use Digest::SHA;
use File::Copy;
use MIME::Parser;

sub main {
	my $conf = &init();
	&process( $conf );
	&cleanup( $conf );
}

sub init {
	my ( $dir, $db ) = @ARGV;
	die "Usage: $0 {output dir} {db file}" unless $dir and $db;
	tie my %db, 'DB_File', $db;

	my $parser = new MIME::Parser;
	$parser->output_dir( '/tmp' );

	return {
		db  => \%db,
		db_size => 3,
		dir => $dir,
		parser => $parser,
	};
}

sub process {
	my ( $conf ) = @_;
	my $entity = $conf->{parser}->parse( \*STDIN ) or die "failed to parse message\n";
	&process_part( $conf, $_ ) foreach $entity->parts_DFS;
#	map { print $_ . ': ' . $conf->{db}{$_} . "\n" } keys %{$conf->{db}};
}

sub cleanup {
	my ( $conf ) = @_;
	$conf->{parser}->filer->purge;
	untie $conf->{db};
}

sub process_part {
	my ( $conf, $part ) = @_;
#	$part->dump_skeleton;
	&save_attachment( $conf, $part ) if &is_attachment( $conf, $part );
}

sub is_attachment {
	my ( $conf, $part ) = @_;
	return 0 unless $part->head->recommended_filename;

	my $sha = new Digest::SHA;
	my $h = $part->bodyhandle->open( 'r' );
	$sha->addfile( $h );
	$h->close;
	my $digest = $sha->hexdigest;
	$conf->{digest} = $digest;
	return ! exists $conf->{db}{$digest};
}

sub save_attachment {
	my ( $conf, $part ) = @_;
	my $filer = $conf->{parser}->filer;
	my $filename = $part->head->recommended_filename;
	$filename = $filer->exorcise_filename( $filename );
	$filename = $filer->find_unused_path( $conf->{dir}, $filename );
	&move( $part->bodyhandle->path, $filename ) or die "failed to save to $filename: $!\n";
#	print 'saved ' . $part->head->recommended_filename . ' to ' . $filename . "\n";

	my $db = $conf->{db};
	my $digest = $conf->{digest};
	$db->{$digest} = 1;
	$db->{head} = $digest unless exists $db->{head};
	$db->{ $db->{tail} } = $digest if exists $db->{tail};
	$db->{tail} = $digest;
	for ( my $ndx = scalar keys %$db; $ndx > $conf->{db_size} + 2; $ndx-- ) {
		my $key = $db->{head};
		$db->{head} = $db->{$key};
		delete $db->{$key};
	}
}

&main();

