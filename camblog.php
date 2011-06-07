<?php 

$workincludefile = "/path/to/photoblog/images.txt";
$picsperpage = 30; # also the number of pics sent in the RSS feed

function print_feed($imagearray) {
	global $picsperpage, $workincludefile, $title, $cc_url;

	$items = array();

	# put relevant data in array
	$curr = 0;
	#$stop = $picsperpage;
	$stop = 10;
	foreach ($imagearray as $image) {
		if (($curr>=$start)&&($curr<$stop)) {
			$items[$curr]['name'] = $image['file'];
			$items[$curr]['link'] = "http://".$_SERVER['SERVER_NAME'].$_SERVER['SCRIPT_NAME']."?image=".$image['file'];
			$items[$curr]['date'] = $image['rfcdate'];
			$items[$curr]['subject'] = $image['subject'];
			$items[$curr]['description'] = $image['description'];
			$items[$curr]['size'] = getimagesize("photoblog/".$image['file']);
		}
		$curr++;
	}

	# set up the beginning of the feed
	header("Last-Modified: " . gmdate("D, d M Y H:i:s", filemtime($workincludefile)) . " GMT");
	header('Content-type: application/rss+xml; charset="utf-8"');
	print "<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<rss version=\"2.0\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" >
<channel>
<title>photo tekniklog</title>
<link>http://".$_SERVER['SERVER_NAME'].$_SERVER['SCRIPT_NAME']."</link>
<description>Teri's moblog.  Sometimes updated, sometimes interesting.&lt;br /&gt;&lt;a href=&quot;$cc_url&quot;&gt;&lt;img src=&quot;http://tekniklr.com/images/somerights.png&quot; border=&quot;0&quot; width=&quot;88&quot; height=&quot;31&quot; align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; alt=&quot;Creative Commons Attribution-ShareAlike License&quot; title=&quot;Creative Commons Attribution-ShareAlike License&quot; /&gt;&lt;/a&gt;</description>
<language>en</language>";

	# print items
	foreach ($items as $item) {
		print "<item>
<title>".$item['subject']."</title>
<description>".$item['date']." ".$item['subject']."</description>
<content:encoded><![CDATA[".$item['description']."<br /><img src=\"http://".$_SERVER['SERVER_NAME']."/photoblog/".$item['name']."\" ".$item['size'][3]." border=\"0\" alt=\"moblog image (".$item['date'].") ".$item['subject']."\" />"."]]></content:encoded>
<link>".$item['link']."</link>
<guid isPermaLink=\"true\">".$item['link']."</guid>
<pubDate>".$item['date']."</pubDate>
</item>\n\n";
	}

	# finish off the feed
	print "</channel>
</rss>\n";

}

function show_image($imagename, $imagearray) {
	global $home, $PHP_SELF, $banned, $table;
	$img_data = $imagearray[$imagename];
	
	$view_image = $img_data['file'];
	$mid_image = "mid".$view_image;
	$fullsize_text = "";
	if (file_exists("photoblog/".$mid_image)) {
		$full_size = getimagesize("photoblog/".$view_image);
		$fullsize_text = "<br /><a href=\"photoblog/$view_image\" onclick=\"javascript: window.open('/photoblog/$view_image', 'blank', 'toolbar=no,width=".$full_size[0].",height=".$full_size[1]."'); return false;\">Full-sized image (".$full_size[0]."x".$full_size[1].", opens in a new window)</a><br />";
		$view_image = $mid_image;
	}	
	
	$img_size = getimagesize("photoblog/".$view_image);
	$width = $img_size[0];
	$height = $img_size[1];
	$width_scale = 600;
	if ($width>$width_scale) {
		$ratio = $width/$width_scale;
		$width = $width_scale;
		$height = round($height/$ratio);
	}
	$images = array_keys($imagearray);
	foreach ($images as $image) {
		if (!isset($last)) {
			$first = $image;
		}
		if ($now) {
			$next = $image;
			$now = false;
		}
		if ($image == $imagename) {
			$prev = $last;
			$now = true;
		}
		$last = $image;
	}
	$left_link = "<a class=\"emph\" href=\"{$_SERVER['PHP_SELF']}?image=$prev\">&lt;-- next snapshot</a>";
	$right_link = "<a class=\"emph\" href=\"{$_SERVER['PHP_SELF']}?image=$next\">previous snapshot --&gt;";
	if (!isset($prev)){
		$left_link = "&nbsp;";
	}
	if (!isset($next)){
		$right_link = "&nbsp;";
	}
	print "<hr />

<center><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"90%\"><tr><td align=\"left\" width=\"33%\">
$left_link
</td>
<td align=\"center\" width=\"34%\"><a href=\"{$_SERVER['PHP_SELF']}\">recent snapshots</a></td>
<td align=\"right\" width=\"33%\">
$right_link
</td></tr></table></center>
<br />
<center>
<a href=\"/photoblog/".$img_data['file']."\" onclick=\"javascript: window.open('/photoblog/".$img_data['file']."', 'blank', 'toolbar=no,width=";
	$jswidth = $img_size[0]+20;
	print "$jswidth,height=";
	$jsheight = $img_size[1]+20;
	print "$jsheight'); return false;\"><img src=\"/photoblog/".$view_image."\" border=\"0\" width=\"$width\" height=\"$height\" alt=\"".$img_data['file']."\" /></a>
$fullsize_text
<br /><em class=\"date\">".$img_data['date']."</em><br />
<strong>".$img_data['subject']."</strong>
</center>
<p style=\"margin: 10px 40px 10px 40px\">\n";
	print $img_data['description'];
	print "</p>\n";
	if (!empty($img_data['extlink'])) {
		print "<p style=\"text-align:center;\"><a href=\"".$img_data['extlink']."\">".$img_data['extlink']."</a></p>\n";
	}
	print "<br />\n\n";
	
}

function show_all($imagearray, $page) {
	global $home, $table, $picsperpage, $heading_text, $max_subject, $cc_url, $cc_image, $cc_name;

	// given page number and number of pics per page, find starting and
	// ending indexes
	$start = 0;
	if ($page == 0) {
		$end = $start+$picsperpage;
	}
	else {
		$start = $page*$picsperpage;
		if ($start > count($imagearray)) {
			$start = 0;
			$end = $start+$picsperpage;
		}
		else {
			$end = $start+$picsperpage;
		}
	}

	// find out how many pages there are
	$numpages = ceil(count($imagearray)/$picsperpage);

	print "<div class=\"hr\">
	<div class=\"leftside\">".count($imagearray)." total images &nbsp;&nbsp;&bull;&nbsp;&nbsp; $picsperpage images/page &nbsp;&nbsp;&bull;&nbsp;&nbsp; page ";
	print $page+1;
	print "/".$numpages."</div>
	<div class=\"rightside\">
		<a class=\"inflate\" href=\"{$_SERVER['PHP_SELF']}?op=rss\"><img src=\"/images/rss.png\" width=\"12\" height=\"12\" border=\"0\" alt=\"rss\" /></a>
	</div>
<div style=\"clear: both;\"></div></div>\n\n";

	print "<div style=\"float: left; align: left;\">";
	if ($page>0) {
		$last = $page-1;
		print "<a href=\"{$_SERVER['PHP_SELF']}?page=$last\">&lt;&lt; previous page</a>";
	}
	print "</div>\n<div style=\"float: right; align: right;\">";
	if ($page<$numpages-1) {
		$next = $page+1;
		print "<a href=\"{$_SERVER['PHP_SELF']}?page=$next\">next page &gt;&gt;</a>";
	}
	print "</div>\n<div style=\"clear: both;\"></div>";

	print "<div style=\"text-align: center; margin: 0px 50px 0px 50px;\">
<br clear=\"all\" />\n\n";

	$curr = 0;
	foreach ($imagearray as $image) {
		if (($curr>=$start)&&($curr<$end)) {
			$thumbname = "/photoblog/tiny".$image['file'];
			$oldsize = getimagesize($GLOBALS['home'].$thumbname);
			$thumbheight = 93;
			$ratio = $oldsize[1]/$thumbheight;
			$thumbwidth = $oldsize[0]/$ratio;
			print "<div class=\"thumbnail\" style=\"height: 140px; width: 130px;\">
<a class=\"art\" href=\"{$_SERVER['PHP_SELF']}?image=".$image['file']."\"><img class=\"art\" src=\"$thumbname\" border=\"0\" width=\"$thumbwidth\" height=\"$thumbheight\" alt=\"".$image['date']."\" title=\"".$image['date']."\" /></a><br />\n";
			print $image['date']."<br />";
			$subject = $image['subject'];
			if (strlen($subject)>$max_subject) {
				$cut_to = $max_subject-3;
				$subject = substr($subject, 0, $cut_to)."...";
			}
			print $subject;
			print "</div>\n";
		}
		$curr++;
	}

	print "</div>\n\n";
	print "<br clear=\"all\" />\n";

	if ($numpages>1) {
		print "<div style=\"text-align: center; font-family: lucidatypewriter, clean, courier, monospace;\">";
		print "<strong>~ Page ~</strong><br />\n";
		for ($i = 0; $i < $numpages; $i++) {
			if ($page==$i) {
				print " <s>$i</s> ";
			}
			else {
				print " <a href=\"{$_SERVER['PHP_SELF']}?page=$i\">$i</a> ";
			}
		}
		print "</div>\n\n";
	}
}

function sanitize($input) {
	$output = str_replace("<br />", "[br]", $input);
	$output = htmlspecialchars($output, ENT_QUOTES);
	$output = str_replace("[br]", " <br />\n", $input);
	return $output;
}

$worklinearray = file($workincludefile);
$worklines =  array_keys($worklinearray);
foreach ($worklines as $line) {
	$element = explode("::", $worklinearray[$line]);
	$thisfile = $element[0];
	$thissubject = sanitize($element[1]);
	$thisdesc = sanitize($element[2]);
	$thisextlink = @$element[3];
	$thisdate = date("M j Y H:i", substr($thisfile, 0, -4));
	$thisrfcdate = date("r", substr($thisfile, 0, -4));
	if (empty($thissubject)) {
		$thissubject = $thisdesc;
		$thisdesc = '';
	}
	$images[$thisfile] = array("file"=>$thisfile, "subject"=>$thissubject, "description"=>$thisdesc, "extlink"=>$thisextlink, "date"=>$thisdate, "rfcdate"=>$thisrfcdate);
}
$images = array_reverse($images, TRUE);
$image = $_GET['image'];
$page = $_GET['page'];
$op = $_GET['op'];
if ($op === "rss") {
	print_feed($images);
}
else {
	include('includes/header.php');

	// connect to database and get picture information
	$table = 'photoblog'; # table to connect to in the database
	
	if (empty($page)) { $page = 0; }
	if (array_key_exists($image, $images)) {
		show_image($image, $images);
	} else {
		show_all($images, $page);
	}
	
	include('includes/footer.php');

}

?>
