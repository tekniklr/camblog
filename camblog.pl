#!/usr/bin/perl -w

use strict;
use MIME::Parser;
use POSIX qw(strftime);
use Date::Manip;
use Getopt::Long;
use Net::Twitter;
use WWW::Shorten::Bitly;
use WWW::Shorten::isgd;
use WWW::Shorten 'isgd';
use HTML::Strip;
use Flickr::Upload;

# receives email message, saves attached image, creates a thumbnail of attached
# images, and maintains index file (which includes message body as picture
# description, as well as time/date the image was added)

#####################################################################
# configuration
#####################################################################
# set timezone
&Date_Init("TZ=EST5EDT");

# set where this should be coming from (everything else will be logged
# and discarded)
my $from_email = 'you@example.com';
# max chars for twitter post
my $tweet_length = 140;
# image destination directory
my $dest	= '/path/to/photoblog/images/directory/';
# images will be scaled to this width
my $width	= 125;
my $midwidth = 600;
# prefix to be added to image thumbnails
my $thumb	= 'tiny';
my $mid = 'mid';
# file which indexes images
my $indexfile	= '/path/to/photoblog/images.txt';
# url of php photoblog script, expecting image filename as GET
my $photoblog	= 'http://example.com/camblog.php?image=';
# whether to run in debug mode
my $debugmode	= 1;
# debugging log file
my $debug	= '/path/to/camblog.log';

# bit.ly
my $bitly_user = 'username';
my $bitly_api = 'R_00000000000000000000000000000000';

# twitter
my $consumer_key = '000000000000000000000';
my $consumer_secret = '0000000000000000000000000000000000000000000';
my $access_token = '000000000000000000000000000000000000000000000000';
my $access_token_secret = '00000000000000000000000000000000000000000';

# flickr
my $flickr_key = '00000000000000000000000000000000';
my $flickr_secret = '0000000000000000';
my $flickr_auth_token = '0000000000000000000000000000000000';
	
#####################################################################
# get needed information
#####################################################################


# read options
my ($do_twitter, $do_flickr);
my $options = GetOptions (
	"twitter|t!" => \$do_twitter,
	"flickr|f!" => \$do_flickr
);

# set defaults to read email
my $parser	= new MIME::Parser;
$parser->ignore_errors(1);
$parser->extract_uuencode(1);
$parser->tmp_recycling(0);
$parser->output_to_core(1);
my $entity	= $parser->parse(\*STDIN);

# set datestamp; to the time the message was sent
my $senddate	= $entity->head->get('Date');
my $date 	= &UnixDate(ParseDate($senddate), "%s");
# if the date is not cromulent, just use the current datestamp
if (!$senddate || !$date) {
	open(DEBUG, ">> $debug") or die "Can't open $debug: $!\n";
	print DEBUG strftime "%a %b %e %H:%M:%S %Y", localtime;
	print DEBUG "\n\tBad date!\n";
	print DEBUG "\tsenddate: $senddate\n";
	print DEBUG "\tdate: $date\n";
	$date = time;
	print DEBUG "\tnew date: $date\n";
	print DEBUG "\n";
	close(DEBUG);
}

# get everything needed out of this email message
my $received	= $entity->head->get('Received');
my $from	= $entity->head->get('From');
my $subject 	= $entity->head->get('Subject');
my $body	= "";
my $file	= "";
my @parts	= $entity->parts;
if (!$subject) {
	$subject = "";
}
my $debugtext = '';

# make sure this is coming from the right place,
# if not, log it and exit
if ($from !~ m/${from_email}/) {
	# open debug/log file
	open(DEBUG, ">> $debug") or die "Can't open $debug: $!\n";
	print DEBUG strftime "%a %b %e %H:%M:%S %Y", localtime;
	print DEBUG "\n\tMessage refused\n";
	print DEBUG "\tSent: $date\n";
	print DEBUG "\tFrom: $from\n";
	print DEBUG "\tReceived: $received\n";
	print DEBUG "\n";
	close(DEBUG);
	exit;
}
elsif ($debugmode) {
	open(DEBUG, ">> $debug") or die "Can't open $debug: $!\n";
	print DEBUG strftime "%a %b %e %H:%M:%S %Y", localtime;
	print DEBUG "\n\tMessage received\n";
	print DEBUG "\tSent: $date\n";
	print DEBUG "\tFrom: $from\n";
	print DEBUG "\tReceived: $received\n";
	print DEBUG "\n";
	close(DEBUG);
}
		
# iterate through the mime parts, doing needed tasks
my $filename = ''; # initialize this here so it can be accessed globally
while(my $part = shift(@parts)) {
	if($part->parts) {
		push @parts,$part->parts; # Nested multi-part
		next;
	}
	my $type=$part->head->mime_type || $part->head->effective_type;
	if ($type =~ m/image\/jpeg/) { # this is the image, process it
		# set filenames
		$file = $date.".jpg";
		$filename = $dest.$file;
		my $thumbname = $dest.$thumb.$file;
		my $midname = $dest.$mid.$file;
		# copy the full image 
		my $io=$part->open("r");
		open(F,">> $filename") or die "Couldn't open ${filename}: $!";
		my $buf;
		while($io->read($buf,1024)) {
			print F $buf;
		}
		close(F);
		$io->close;
		# copy the full image to the thumbnail and mid images
		my $copy1 = `/bin/cp $filename $thumbname`;
		my $copy2 = `/bin/cp $filename $midname`;
		# resize the thumbnail and mid images
		my $resize1 = `/usr/bin/mogrify -geometry $width $thumbname`;
		my $resize2 = `/usr/bin/mogrify -geometry $midwidth $midname`;	
		# make the images world readable
		my $chmod = `/bin/chmod a+r $filename $thumbname $midname`;
		if ($debugmode) {
			$debugtext .= strftime "%a %b %e %H:%M:%S %Y", localtime;
			$debugtext .= "\n\tSubject: $subject\n";
			$debugtext .= "\tSent: $date\n";
			$debugtext .= "\tFrom: $from\n";
			$debugtext .= "\tReceived: $received\n";
			$debugtext .= "\tBody: $body\n";
			$debugtext .= "\tFilename: $filename\n";
			$debugtext .= "\tThumbnail: $thumbname\n";
			#$debugtext .= "\tOutput of cp: $copy1\n";
			#$debugtext .= "\tOutput of cp: $copy2\n";
			#$debugtext .= "\tOutput of mogrify: $resize1\n";
			#$debugtext .= "\tOutput of mogrify: $resize2\n";
			#$debugtext .= "\tOutput of chmod: $chmod\n";
		}
	}
	elsif ($type =~ m/text|message/) { # text, save is as the description
		my $io=$part->open("r");
		my $buf;
		while($io->read($buf,1024)) {
			$body .= $buf;
		}
	}
}

if (!$file) {
	goto END;
}

# remove newlines
$subject =~ s!\n!!g;
$subject =~ s!\s+! !g;
$body =~ s!\r!!g;
$body =~ s!\n!<br />!g;

# generate line, replacing '::' in subject and body
my $line_subject = $subject;
$line_subject =~ s/:/&#58;/g;
my $line_body = $body;
$line_body =~ s/:/&#58;/g;
my $line = "${file}::${line_subject}::${line_body}";
# add entry to index file
open(INDEX, ">> $indexfile") or die "Can't open $indexfile: $!\n";
print INDEX $line;
close(INDEX);

# link will be used for twitter and/or flickr
my $link = "${photoblog}${file}";

if ($do_twitter) {
	# craft post to send to twitter
	my $tweet = $subject;
	$tweet ||= $body;
	my $tries = 0;
	my $max_tries = 10;
	BITLY:
	$tries++;
	my $shortlink = WWW::Shorten::Bitly::makeashorterlink($link, $bitly_user, $bitly_api);
	if (!$shortlink) {
		if ($tries < $max_tries) {
			# had to add this kludge because sometimes bit.ly wouldn't work
			goto BITLY;
		}
		# if bit.ly failed, try is.gd
		$shortlink = WWW::Shorten::isgd::makeashorterlink($link);
		if (!$shortlink) {
			# if bit.ly and is.gd failed, use the whole link, though the
			# message will likely be truncated
			$shortlink = $link;
		}
	}
	
	# remove any markup
	my $hs = HTML::Strip->new();
	$tweet = $hs->parse($tweet);
	$hs->eof;

	# the link is 17 characters, if the text is > 122 characters, 
	# truncate it for twitter
	my $linkchars = length($shortlink);
	my $numchars = length($tweet);
	my $maxlength = $tweet_length - 1 - $linkchars; 
	if ($numchars > $maxlength) {
		my $newlength = $maxlength - 3;
		$tweet = substr $tweet, 0, $newlength;
		$tweet .= "...";
	}
	
	# append image url
	$tweet .= " $shortlink";

	# tweet it
	my $twitter = Net::Twitter->new(
		traits => [qw/OAuth API::REST/],
		consumer_key        => $consumer_key,
		consumer_secret     => $consumer_secret,
		access_token        => $access_token,
		access_token_secret => $access_token_secret,
	);
	my $result = $twitter->update("$tweet");
	
	if ($debugmode) {
		$debugtext .= "\tLink: $link\n";
		$debugtext .= "\tShort Link: $shortlink\n";
		$debugtext .= "\tTweet: $tweet\n";
	}
}

if ($do_flickr) {
	# send image to flickr
	my $ua = Flickr::Upload->new(
		{
			'key' => $flickr_key,
			'secret' => $flickr_secret
		});
	my $flickr_desc = $subject;
	$flickr_desc ||= $body;
	my $photoid = $ua->upload(
		'photo' => $filename,
		'auth_token' => $flickr_auth_token,
		'tags' => 'moblog',
		'is_public' => 1,
		'is_friend' => 1,
		'is_family' => 1,
		'title' => $file,
		'description' => "$flickr_desc \n<a href='$link'>$link</a>",
		'async' => 0
	);
	if ($debugmode) {
		if ($photoid) {
			$debugtext .= "\tFlickr photo ID: $photoid\n";
		}
		else {
			$debugtext .= "\tFlickr photo upload failed!\n";
		}
	}
	if ($photoid) {
		# add flickr link to image description
		my $flickr_link = "http://www.flickr.com/photos/tekniklr/${photoid}/";
		open(INDEX, ">> $indexfile") or die "Can't open $indexfile: $!\n";
		print INDEX "::$flickr_link";
		close(INDEX);
	}
}

# make sure the index is ready for the next image
open(INDEX, ">> $indexfile") or die "Can't open $indexfile: $!\n";
print INDEX "\n";
close(INDEX);

END:
if ($debugmode) {
	# open debug/log file
	open(DEBUG, ">> $debug") or die "Can't open $debug: $!\n";
	print DEBUG $debugtext;
	print DEBUG "\n";
	close(DEBUG);
}

