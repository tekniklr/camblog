#!/usr/bin/perl -w

use strict;
use MIME::Parser;
use POSIX qw(strftime);
use Date::Manip;

# receives email message, saves attached image, creates a thumbnail of attached
# images, and maintains index file (which includes message body as picture
# description, as well as time/date the image was added)

#####################################################################
# configuration
#####################################################################
# set timezone
&Date_Init("TZ=EST5EDT");

# your phone number, used for spoof protection
my $phone = '1235551234';
# your cell provider's SMTP host, used for spoof protection
my $smtp = 'smtp.vzwpix.com';
# image destination directory
my $dest	= '/path/to/photoblog/images/directory/';
# images will be scaled to this width
my $width	= 125;
# prefix to be added to image thumbnails
my $thumb	= 'tiny';
# file which indexes images
my $indexfile	= '/path/to/photoblog/images.txt';
# whether to run in debug mode
my $debugmode	= 0;
# debugging log file
my $debug	= '/path/to/camblog.log';

#####################################################################
# get needed information
#####################################################################

# set defaults to read email
my $parser	= new MIME::Parser;
$parser->ignore_errors(1);
$parser->extract_uuencode(1);
$parser->tmp_recycling(0);
$parser->output_to_core(1);
my $entity	= $parser->parse(\*STDIN);

# set datestamp; to the time the message was sent
my $senddate	= $entity->head->get('Date');
my $date 	= &UnixDate(ParseDate($senddate), "%s");;

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

# make sure this is coming from the right place,
# if not, log it and exit
if (($received !~ m/$smtp/) && ($from !~ m/$phone/)) {
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
		
# iterate through the mime parts, doing needed tasks
while(my $part = shift(@parts)) {
	if($part->parts) {
		push @parts,$part->parts; # Nested multi-part
		next;
	}
	my $type=$part->head->mime_type || $part->head->effective_type;
	if ($type =~ m/image\/jpeg/) { # this is the image, process it
		# set filenames
		$file = $date.".jpg";
		my $filename = $dest.$file;
		my $thumbname = $dest.$thumb.$file;
		# copy the full image 
		my $io=$part->open("r");
		open(F,">> $filename") or die "Couldn't open ${filename}: $!";
		my $buf;
		while($io->read($buf,1024)) {
			print F $buf;
		}
		close(F);
		$io->close;
		# copy the full image to the thumbnail
		my $copy = `/bin/cp $filename $thumbname`;
		# resize the thumbnail
		my $resize = `/usr/bin/mogrify -geometry $width $thumbname`;
		# make the images world readable
		my $chmod = `/bin/chmod a+r $filename $thumbname`;
		if ($debugmode) {
			# open debugign file
			open(DEBUG, ">> $debug") or die "Can't open $debug: $!\n";
			print DEBUG strftime "%a %b %e %H:%M:%S %Y", localtime;
			print DEBUG "\n\tSubject: $subject\n";
			print DEBUG "\tSent: $date\n";
			print DEBUG "\tFrom: $from\n";
			print DEBUG "\tReceived: $received\n";
			print DEBUG "\tBody: $body\n";
			print DEBUG "\tFilename: $filename\n";
			print DEBUG "\tThumbnail: $thumbname\n";
			print DEBUG "\tOutput of cp: $copy\n";
			print DEBUG "\tOutput of mogrify: $resize\n";
			print DEBUG "\tOutput of chmod: $chmod\n";
			print DEBUG "\n";
			close(DEBUG);
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

if ($file) {
	# remove newlines
	$subject =~ s,\n,,g;
	$body =~ s!\r!!g;
	$body =~ s!\n!<br />!g;
	# remove stupid Verizon ads
	if ($body =~ /(.*)(This message was sent using Picture Messaging from Verizon Wireless!)/i) {
		$body = "$1";
	}
	if ($body =~ /(.*)(<br \/><br \/><br \/>)/i) {
		$body = "$1";
	}
	# add entry to index file
	my $line = "${file}::${subject}::${body}\n";
	open(INDEX, ">> $indexfile") or die "Can't open $indexfile: $!\n";
	print INDEX $line;
	close(INDEX);
}
