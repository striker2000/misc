#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use JSON;
use LWP::UserAgent;
use Pod::Usage;

my $access_token;
GetOptions(
	'token=s' => \$access_token,
) or pod2usage();

my $audios_url = $ARGV[0] or pod2usage();
my $download_dir = $ARGV[1] or pod2usage();

my ( $owner_id ) = $audios_url =~ /^https?:\/\/vk\.com\/audios(-?\d+)$/;
unless ( $owner_id ) {
	pod2usage( 'Bad audios URL' );
}

my $ua = LWP::UserAgent->new;

my $meta = {};
if ( -e "$download_dir/META.json" ) {
	open my $fh, '<', "$download_dir/META.json" or die $!;
	my $content = join '', <$fh>;
	close $fh;
	$meta = decode_json( $content );
}

my $res = $ua->get( 'https://api.vk.com/method/audio.get' .
	"?owner_id=$owner_id&access_token=$access_token" );

unless ( $res->is_success ) {
	die 'Can not get audios: ' . $res->status_line . "\n";
}

my $data = decode_json( $res->decoded_content );

if ( $data->{error} ) {
	my $code = $data->{error}->{error_code};
	my $msg  = $data->{error}->{error_msg};
	die "Can not get audios: $code $msg\n";
}

my $total = shift @{ $data->{response} };
my $added = 0;
my $removed = 0;

my @audio_ids;
foreach my $audio ( @{ $data->{response} } ) {
	unless ( $meta->{ $audio->{aid} } ) {
		my $fn = "$download_dir/$audio->{aid}.mp3";
		`wget -nv $audio->{url} -O $fn`;

		if ( $audio->{lyrics_id} ) {
			$res = $ua->get( 'https://api.vk.com/method/audio.getLyrics' .
				"?lyrics_id=$audio->{lyrics_id}&access_token=$access_token" );
			if ( $res->is_success ) {
				$audio->{lyrics} = decode_json( $res->decoded_content );
			}
		}

		$meta->{ $audio->{aid} } = $audio;
		$added++;
	}
	push @audio_ids, $audio->{aid};
}

foreach my $audio_id ( keys %{ $meta } ) {
	unless ( $audio_id ~~ @audio_ids ) {
		delete $meta->{ $audio_id };
		$removed++;
	}
}

opendir my $dh, $download_dir or die $!;
while ( my $fn = readdir $dh ) {
	if ( $fn =~ /(\d+)\.mp3$/ ) {
		my $audio_id = $1;
		unless ( $audio_id ~~ @audio_ids ) {
			unlink "$download_dir/$fn" or die $!;
		}
	}
}
closedir $dh;

open my $fh, '>', "$download_dir/META.json" or die $!;
print $fh encode_json( $meta );
close $fh;

print "In album: $total\nAdded: $added\nRemoved: $removed\n"

__END__

=head1 NAME

vk-sync-audio.pl - synchronize audios from VK album with local directory

=head1 SYNOPSIS

 vk-sync-audio.pl [options] audios_url local_path

 Options:
   --token     access token
