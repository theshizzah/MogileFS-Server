package MogileFS::Config;
use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($DEBUG config);

our ($DEFAULT_CONFIG, $DEFAULT_MOG_ROOT, $MOG_ROOT, $MOGSTORED_STREAM_PORT, $DEBUG, $USE_HTTP);
$DEBUG = 0;
$DEFAULT_CONFIG = "/etc/mogilefs/mogilefsd.conf";
$DEFAULT_MOG_ROOT = "/mnt/mogilefs";
$MOGSTORED_STREAM_PORT = 7501;

my %conf;
sub set_config {
    my ($k, $v) = @_;
    return $conf{$k} = $v;
}

set_config("mogstored_stream_port" => $MOGSTORED_STREAM_PORT);

our (
    %cmdline,
    %cfgfile,
    $config,
    $skipconfig,
    $daemonize,
    $db_dsn,
    $db_user,
    $db_pass,
    $conf_port,
    $query_jobs,
    $delete_jobs,
    $replicate_jobs,
    $reaper_jobs,
    $monitor_jobs,
    $mog_root,
    $min_free_space,
    $max_disk_age,
    $node_timeout,          # time in seconds to wait for storage node responses
   );

our $default_mindevcount;

sub load_config {
    my $dummy_workerport;

    # Command-line options will override
    Getopt::Long::Configure( "bundling" );
    Getopt::Long::GetOptions(
                             'c|config=s'    => \$config,
                             's|skipconfig'  => \$skipconfig,
                             'd|debug+'      => \$cmdline{debug},
                             'D|daemon'      => \$cmdline{daemonize},
                             'dsn=s'         => \$cmdline{db_dsn},
                             'dbuser=s'      => \$cmdline{db_user},
                             'dbpass=s'      => \$cmdline{db_pass},
                             'r|mogroot=s'   => \$cmdline{mog_root},
                             'p|confport=i'  => \$cmdline{conf_port},
                             'w|workers=i'   => \$cmdline{query_jobs},
                             'no_http'       => \$cmdline{no_http},
                             'workerport=i'  => \$dummy_workerport,  # eat it for backwards compat
                             'maxdiskage=i'  => \$cmdline{max_disk_age},
                             'minfreespace=i' => \$cmdline{min_free_space},
                             'default_mindevcount=i' => \$cmdline{default_mindevcount},
                             'node_timeout=i' => \$cmdline{node_timeout},
                             );

    # warn of old/deprecated options
    warn "The command line option --workerport is no longer needed (and has no necessary replacement)\n"
        if $dummy_workerport;

    $config = $DEFAULT_CONFIG if !$config && -r $DEFAULT_CONFIG;

    # Read the config file if one was specified
    if ($config && !$skipconfig) {
        open my $cf, "<$config" or die "open: $config: $!";

        my $configLine = qr{
            ^\s*                    # Leading space
                (\w+)                   # Key
                \s+ =? \s*              # space + optional equal + optional space
                (.+?)                   # Value
                \s*$                    # Trailing space
            }x;

        my $linecount = 0;
        while (defined( my $line = <$cf> )) {
            $linecount++;
            next if $line =~ m!^\s*(\#.*)?$!;
            die "Malformed config file (line $linecount)" unless $line =~ $configLine;

            my ( $key, $value ) = ( $1, $2 );
            print STDERR "Setting '$key' to '$value'\n" if $cmdline{debug};
            $cfgfile{$key} = $value;
        }

        close $cf;
    }

    # Fill in defaults for those values which were either loaded from config or
    # specified on the command line. Command line takes precendence, then values in
    # the config file, then the defaults.
    $daemonize      = choose_value( 'daemonize', 0, 1 );
    $db_dsn         = choose_value( 'db_dsn', "DBI:mysql:mogilefs" );
    $db_user        = choose_value( 'db_user', "mogile" );
    $db_pass        = choose_value( 'db_pass', "", 1 );
    $conf_port      = choose_value( 'conf_port', 7001 );
    $MOG_ROOT       = set_config('root',
                                 choose_value( 'mog_root', $DEFAULT_MOG_ROOT )
                                 );
    $query_jobs     = set_config("query_jobs",
                                 choose_value( 'listener_jobs', undef) || # undef if not present, then we
                                 choose_value( 'query_jobs', 20 ));       # fall back to query_jobs, new name
    $delete_jobs    = choose_value( 'delete_jobs', 1 );
    $replicate_jobs = choose_value( 'replicate_jobs', 1 );
    $reaper_jobs    = choose_value( 'reaper_jobs', 1 );
    $monitor_jobs   = choose_value( 'monitor_jobs', 1 );
    $min_free_space = choose_value( 'min_free_space', 100 );
    $max_disk_age   = choose_value( 'max_disk_age', 5 );
    $DEBUG          = choose_value( 'debug', 0, 1 );
    $USE_HTTP       = ! choose_value( 'no_http', 0, 1);
    $default_mindevcount = choose_value( 'default_mindevcount', 2 );
    $node_timeout   = choose_value( 'node_timeout', 2 );
}

### FUNCTION: choose_value( $name, $default[, $boolean] )
sub choose_value ($$;$) {
    my ( $name, $default, $boolean ) = @_;
    return set_config($name, $cmdline{$name}) if defined $cmdline{$name};
    return set_config($name, $cfgfile{$name}) if defined $cfgfile{$name};
    return set_config($name, $default);
}

sub config {
    my ($class, $k) = @_;
    die "No config variable '$k'" unless defined $conf{$k};
    return $conf{$k};
}

sub http_mode   { return $USE_HTTP; }

1;

# Local Variables:
# mode: perl
# c-basic-indent: 4
# indent-tabs-mode: nil
# End:
