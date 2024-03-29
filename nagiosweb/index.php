<?php
// Allow specifying main window URL for permalinks, etc.
$url = 'cgi-bin/tac.cgi';

if ("no" == "yes" && isset($_GET['corewindow'])) {

	// The default window url may have been overridden with a permalink...
	// Parse the URL and remove permalink option from base.
	$a = parse_url($_GET['corewindow']);

	// Build the base url.
	$url = htmlentities($a['path']).'?';
	$url = (isset($a['host'])) ? $a['scheme'].'://'.$a['host'].$url : '/'.$url;

	$query = isset($a['query']) ? $a['query'] : '';
	$pairs = explode('&', $query);
	foreach ($pairs as $pair) {
		$v = explode('=', $pair);
		if (is_array($v)) {
			$key = urlencode($v[0]);
			$val = urlencode(isset($v[1]) ? $v[1] : '');
			$url .= "&$key=$val";
		}
	}
	if (preg_match("/^http:\/\/|^https:\/\/|^\//", $url) != 1)
		$url = "main.php";
}

$this_year = '2022';
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">

<html>
<head>
	<meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
	<title>SAMM: <?php echo $_SERVER['SERVER_NAME']; ?></title>
	<link rel="shortcut icon" href="images/favicon.ico" type="image/ico">

	<script LANGUAGE="javascript">
		var n = Math.round(Math.random() * 10000000000);
		document.cookie = "NagFormId=" + n.toString(16);
	</script>
</head>

<frameset cols="180,*" style="border: 0px; framespacing: 0px">
	<frame src="side.php" name="side" frameborder="0" style="">
	<frame src="<?php echo $url; ?>" name="main" frameborder="0" style="">

	<noframes>
		<!-- This page requires a web browser which supports frames. -->
		<h2>SAMM</h2>
		<p align="center">
			<a href="https://www.samanagroup.com/">www.samanagroup.com</a><br>
		</p>
		<p>
			<i>Note: These pages require a browser which supports frames</i>
		</p>
	</noframes>
</frameset>

</html>
