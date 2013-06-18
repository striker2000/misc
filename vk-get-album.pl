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

my $album_url = $ARGV[0] or pod2usage();

my ( $user_id, $album_id ) =
	$album_url =~ /^http:\/\/vk\.com\/album(-?\d+)_(\d+)$/;
unless ( $user_id && $album_id ) {
	pod2usage( 'Bad album URL' );
}

my $ua = LWP::UserAgent->new;

my $api_url = "https://api.vk.com/method/photos.get?aid=$album_id";
if ( $user_id > 0 ) {
	$api_url .= "&uid=$user_id";
}
else {
	$api_url .= '&gid=' . abs $user_id;
}
if ( $access_token ) {
	$api_url .= "&access_token=$access_token";
}

my $res = $ua->get( $api_url );

if ( $res->is_success ) {
	my $data = decode_json( $res->decoded_content );

	if ( $data->{error} ) {
		my $code = $data->{error}->{error_code};
		my $msg  = $data->{error}->{error_msg};
		die "Can not get album: $code $msg\n";
	}

	my $total = scalar @{ $data->{response} };
	print "$total photo(s) in album\n";

	my $cnt = 0;
	my $downloaded = 0;

	foreach my $photo ( @{ $data->{response} } ) {
		my $url = $photo->{src_xxxbig}
			// $photo->{src_xxbig}
			// $photo->{src_xbig}
			// $photo->{src_big};
		my $fn = sprintf '%d-%03d.jpg', $album_id, $cnt;

		my $res = $ua->get( $url, ':content_file' => $fn );

		my $status;
		if ( $res->is_success ) {
			$downloaded++;
			$status = 'OK';
		}
		else {
			$status = 'FAIL (' . $res->status_line . ')';
		}
		print "$fn: $status\n";

		$cnt++;
	}

	print "Downloaded: $downloaded / $total\n";
}
else {
	die 'Can not get album: ' . $res->status_line . "\n";
}

__END__

=head1 NAME

vk-get-album.pl - download all photos from VK album

=head1 SYNOPSIS

 vk-get-album.pl [options] album_url

 Options:
   --token     access token
