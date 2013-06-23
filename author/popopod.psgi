use strict;
use YAML::Tiny;
use Plack::Builder;
use Pod::Simple::XHTML;
use Plack::Request;
use Plack::Loader;
use File::Basename;
use Path::Class;
use Text::MicroTemplate qw(:all);

# FIX: directory traversal

my $meta = eval { YAML::Tiny->read('META.yml')->[0] };
my $PROJECT_NAME = eval { $meta->{name} };

sub no_index_regexp {
    my @no_index;
    if (-f 'META.yml') {
        my @dir = @{$meta->{no_index}->{directory}};
        if (@dir) {
            push @no_index, @dir;
        }
    }
    my $re = join('|', map { quotemeta "$_/" } @no_index);
    return qr/^(?:$re)/;
}

sub render_pod_page {
    render_mt(<<'...', @_);
? my ($pod_html) = @_;
<!doctype html>
<html>
<head>
<link rel="stylesheet" type="text/css" href="/podstyle.css" />
</head>
<body>
<a href="/">top</a>
<div class="pod">
<?= $pod_html ?>
</div>
</body>
</html>
...
}

sub render_root_page {
    render_mt(<<'...', @_);
? my ($title, $files) = @_;
? my $i;
<!doctype html>
<html>
<head>
<link rel="stylesheet" type="text/css" href="/podstyle.css" />
</head>
<body>
<div class="box">
<h1 class="t1"><?= $title ?></h1>
</div>

<div id="list">
<div class="box">
<h2 class="t2">Modules</h2>
<table width="100%">
? for my $file (@$files) {
    <tr class="<?= ( $i++ % 2 == 0 ) ? 'r' : 's' ?>">
        <td nowrap="nowrap"><a href="<?= $file->{path} ?>"><?= $file->{name} ?></a></td>
        <td width='99%'><small><?= $file->{title} ?></small></td>
    </tr>
? }
</table>
</div>
</div>
</body>
</html>
...
}

sub dispatch_root {
    my @names;
    my $no_index_regexp = no_index_regexp();
    dir('.')->recurse(
        callback => sub {
            my $f = shift;
            return unless -f $f;
            my $fname = "$f";
            $fname =~ s!^\./!!;
            return if $fname =~ m{^\.git/};
            return if $fname =~ m{^README.pod};
            return if $fname =~ m{^blib/};
            return if $fname =~ $no_index_regexp;
            my $src = $f->slurp(iomode => '<:utf8');
            if ($src =~ /\n=head1\s+NAME\s+(.+)\s+-\s+(.+)/) {
                my $name  = $1;
                my $title = $2;
                $name =~ s/\n//;
                my $path = $f->relative(dir('.'));
                push @names,
                  +{
                    name  => $1,
                    title => $2,
                    path  => $path,
                  };
            }
        },
    );
    [200, ['Content-Type' => 'text/html; charset=utf-8'], [render_root_page($PROJECT_NAME, \@names)]];
}

sub dispatch_pod {
    my $req = shift;
    my $path = $req->path_info;
    $path =~ s!^/!!;
    my $parser = Pod::Simple::XHTML->new();
    $parser->output_string(\my $html);
    $parser->parse_file($path);
    $html = render_pod_page(encoded_string $html);
    [200, ['Content-Type' => 'text/html; charset=utf-8'], [$html]];
}

sub dispatch_pod_style_css {
    my $req = shift;
    [200, ['Content-Type' => 'text/css'], [<<"..."]];

BODY, .logo { background: white; }

BODY {
  color: black;
  font-family: arial,sans-serif;
  margin: 0;
  padding: 1ex;
}

TABLE {
  border-collapse: collapse;
  border-spacing: 0;
  border-width: 0;
  color: inherit;
}

IMG { border: 0; }
FORM { margin: 0; }
input { margin: 2px; }

.logo {
  float: left;
  width: 264px;
  height: 77px;
}

.front .logo  {
  float: none;
  display:block;
}

.front .searchbox  {
  margin: 2ex auto;
  text-align: center;
}

.front .menubar {
  text-align: center;
}

.menubar {
  background: #006699;
  margin: 1ex 0;
  padding: 1px;
} 

.menubar A {
  padding: 0.8ex;
  font: bold 10pt Arial,Helvetica,sans-serif;
}

.menubar A:link, .menubar A:visited {
  color: white;
  text-decoration: none;
}

.menubar A:hover {
  color: #ff6600;
  text-decoration: underline;
}

A:link, A:visited {
  background: transparent;
  color: #006699;
}

A[href="#POD_ERRORS"] {
  background: transparent;
  color: #FF0000;
}

TD {
  margin: 0;
  padding: 0;
}

DIV {
  border-width: 0;
}

DT {
  margin-top: 1em;
}

.credits TD {
  padding: 0.5ex 2ex;
}

.huge {
  font-size: 32pt;
}

.s {
  background: #dddddd;
  color: inherit;
}

.s TD, .r TD {
  padding: 0.2ex 1ex;
  vertical-align: baseline;
}

TH {
  background: #bbbbbb;
  color: inherit;
  padding: 0.4ex 1ex;
  text-align: left;
}

TH A:link, TH A:visited {
  background: transparent;
  color: black;
}

.box {
  border: 1px solid #006699;
  margin: 1ex 0;
  padding: 0;
}

.distfiles TD {
  padding: 0 2ex 0 0;
  vertical-align: baseline;
}

.manifest TD {
  padding: 0 1ex;
  vertical-align: top;
}

.l1 {
  font-weight: bold;
}

.l2 {
  font-weight: normal;
}

.t1, .t2, .t3, .t4  {
  background: #006699;
  color: white;
}
.t4 {
  padding: 0.2ex 0.4ex;
}
.t1, .t2, .t3  {
  padding: 0.5ex 1ex;
}

/* IE does not support  .box>.t1  Grrr */
.box .t1, .box .t2, .box .t3 {
  margin: 0;
}

.t1 {
  font-size: 1.4em;
  font-weight: bold;
  text-align: center;
}

.t2 {
  font-size: 1.0em;
  font-weight: bold;
  text-align: left;
}

.t3 {
  font-size: 1.0em;
  font-weight: normal;
  text-align: left;
}

/* width: 100%; border: 0.1px solid #FFFFFF; */ /* NN4 hack */

.datecell {
  text-align: center;
  width: 17em;
}

.cell {
  padding: 0.2ex 1ex;
  text-align: left;
}

.label {
  background: #aaaaaa;
  color: black;
  font-weight: bold;
  padding: 0.2ex 1ex;
  text-align: right;
  white-space: nowrap;
  vertical-align: baseline;
}

.categories {
  border-bottom: 3px double #006699;
  margin-bottom: 1ex;
  padding-bottom: 1ex;
}

.categories TABLE {
  margin: auto;
}

.categories TD {
  padding: 0.5ex 1ex;
  vertical-align: baseline;
}

.path A {
  background: transparent;
  color: #006699;
  font-weight: bold;
}

.pages {
  background: #dddddd;
  color: #006699;
  padding: 0.2ex 0.4ex;
}

.path {
  background: #dddddd;
  border-bottom: 1px solid #006699;
  color: #006699;
 /*  font-size: 1.4em;*/
  margin: 1ex 0;
  padding: 0.5ex 1ex;
}

.menubar TD {
  background: #006699;
  color: white;
}

.menubar {
  background: #006699;
  color: white;
  margin: 1ex 0;
  padding: 1px;
}

.menubar .links     {
  background: transparent;
  color: white;
  padding: 0.2ex;
  text-align: left;
}

.menubar .searchbar {
  background: black;
  color: black;
  margin: 0px;
  padding: 2px;
  text-align: right;
}

A.m:link, A.m:visited {
  background: #006699;
  color: white;
  font: bold 10pt Arial,Helvetica,sans-serif;
  text-decoration: none;
}

A.o:link, A.o:visited {
  background: #006699;
  color: #ccffcc;
  font: bold 10pt Arial,Helvetica,sans-serif;
  text-decoration: none;
}

A.o:hover {
  background: transparent;
  color: #ff6600;
  text-decoration: underline;
}

A.m:hover {
  background: transparent;
  color: #ff6600;
  text-decoration: underline;
}

table.dlsip     {
  background: #dddddd;
  border: 0.4ex solid #dddddd;
}

.pod PRE     {
  background: #eeeeee;
  border: 1px solid #888888;
  color: black;
  padding: 1em;
  white-space: pre;
}

.pod H1      {
  background: transparent;
  color: #006699;
  font-size: large;
}

.pod H2      {
  background: transparent;
  color: #006699;
  font-size: medium;
}

.pod IMG     {
  vertical-align: top;
}

.pod .toc A  {
  text-decoration: none;
}

.pod .toc LI {
  line-height: 1.2em;
  list-style-type: none;
}

.faq DT {
  font-size: 1.4em;
  font-weight: bold;
}

.chmenu {
  background: black;
  color: red;
  font: bold 1.1em Arial,Helvetica,sans-serif;
  margin: 1ex auto;
  padding: 0.5ex;
}

.chmenu TD {
  padding: 0.2ex 1ex;
}

.chmenu A:link, .chmenu A:visited  {
  background: transparent;
  color: white;
  text-decoration: none;
}

.chmenu A:hover {
  background: transparent;
  color: #ff6600;
  text-decoration: underline;
}

.column {
  padding: 0.5ex 1ex;
  vertical-align: top;
}

.datebar {
  margin: auto;
  width: 14em;
}

.date {
  background: transparent;
  color: #008000;
}

.footer {
  margin-top: 1ex;
  text-align: right;
  color: #006699;
  font-size: x-small;
  border-top: 1px solid #006699;
  line-height: 120%;
}

.front .footer {
  border-top: none;
}

.search_highlight {
    color: #ff6600;
}

.def_HorzCross {
    color: #000000;
    background-color: #313b30;
}

.def_VertCross {
    color: #000000;
    background-color: #313b30;
}

.def_Number {
    color: #00a800;
}

.def_NumberDec {
    color: #008c00;
}

.def_NumHex {
    color: #008000;
}

.def_NumberBin {
    color: #007d00;
}

.def_NumberOct {
    color: #008c00;
}

.def_NumberFloat {
    color: #009f00;
}

.def_NumberSuffix {
    color: #006600;
}

.def_String {
    color: #00c4c4;
}

.def_Special {
    colo}

.def_Keyword {
    color: #A52A2A;
    font-weight: bold;
}

.def_KeywordStrong {
    color: #904050;
}

.def_ClassKeyword {
    color: #bb7977;
    font-weight: bold;
}

.def_TypeKeyword 
.def_Register {
    color: #d0d09f;
}

.def_Constant {
    color: #007d45;
}

.def_BooleanConstant {
    color: #0f4d75;
}

.def_Var {
    color: #007997;
}

.def_VarStrong {
    color: #007997;
}

.def_Identifier {
    color: #005fd2;
}

.def_Directive {
    color: #008073;
}

.def_Param {
    color: #64810c;
}

.def_Tag {
    color: #f6c1d0;
}

.def_OpenTag {
    color: #ff8906;
}

.def_CloseTag {
    color: #fb8400;
}

.def_Label {
    color: #e34adc;
}

.def_LabelStrong {
    color: #000000;
    background-color: #a8a800;
}

.def_Insertion {
    color: #ffffff;
    background-color: #281800;
}

.def_InsertionStart {
    color: #800000;
    background-color: #ffffa4;
}

.def_InsertionEnd {
    color: #800000;
    background-color: #ffffa4;
}

.def_Error {
    color: #ffffff;
    background-color: #dd0000;
}

.def_ErrorText {
    color: #ee00ee;
}

.def_TODO {
    color: #ffffff;
    background-color: #3c215f;
}

.def_Debug {
    color: #011a47;
    background-color: #007084;
}

.def_Path {
    color: #40015a;
}

.def_URL {
    color: #6070ec;
}

.def_EMail {
    color: #a160f4;
}

.def_Date {
    color: #009797;
}

.def_Time {
    color: #8745a0;
}

.def_PairStart {
    color: #aa4444;
}

.def_PairEnd {
    color: #aa4444;
}
...
}

my $app = builder {
    enable 'ContentLength';

    sub {
        my $req = Plack::Request->new(shift);

        if ($req->path_info eq '/') {
            return dispatch_root($req);
        } if ($req->path_info eq '/podstyle.css') {
            return dispatch_pod_style_css($req);
        } if ($req->path_info eq '/favicon.ico') {
            return [200, [], []];
        } else {
            return dispatch_pod($req);
        }
    }
};

if (basename($0) eq basename(__FILE__)) {
    Plack::Loader->auto(port => 1999)->run($app);
} else {
    $app;
}

