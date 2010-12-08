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

sub no_index_regexp {
    my @no_index;
    if (-f 'META.yml') {
        my $meta = YAML::Tiny->read('META.yml');
        my @dir = @{$meta->[0]->{no_index}->{directory}};
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
<style>
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


</style>
</head>
<body>
<a href="/">top</a>
<?= $pod_html ?>
</body>
</html>
...
}

sub render_root {
    render_mt(<<'...', @_);
? my ($files) = @_;
<!doctype html>
<html>
<head>
<style>
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


</style>
</head>
<body>
<table>
? for my $file (@$files) {
    <tr><th align="left"><a href="<?= $file->{path} ?>"><?= $file->{name} ?></a></th><td><?= $file->{title} ?></td></tr>
? }
</table>
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
    [200, ['Content-Type' => 'text/html; charset=utf-8'], [render_root(\@names)]];
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

my $app = builder {
    enable 'ContentLength';

    sub {
        my $req = Plack::Request->new(shift);

        if ($req->path_info eq '/') {
            return dispatch_root($req);
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

