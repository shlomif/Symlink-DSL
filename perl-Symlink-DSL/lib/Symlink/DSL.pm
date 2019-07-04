package Symlink::DSL;

use strict;
use warnings;
use autodie;
use Cwd qw/ getcwd /;
use File::Basename qw/ dirname /;
use File::Path qw/ mkpath /;

sub new
{
    my $class = shift;

    my $self = bless {}, $class;

    $self->_init(@_);

    return $self;
}

sub _init
{
    my ( $self, $args ) = @_;
    $self->{dir} = $args->{dir};
    $self->skip_re( $args->{skip_re} );
    $self->manifest( $self->dir . "/setup.symlinks.manifest.txt" );

    return;
}

sub manifest
{
    my $self = shift;

    if (@_)
    {
        $self->{manifest} = shift;
    }

    return $self->{manifest};
}

sub skip_re
{
    my $self = shift;

    if (@_)
    {
        $self->{skip_re} = shift;
    }

    return $self->{skip_re};
}

sub dir
{
    my $self = shift;

    if (@_)
    {
        $self->{dir} = shift;
    }

    return $self->{dir};
}

sub handle_line
{
    my ( $self, $args ) = @_;

    my $l       = $args->{line};
    my $dir     = $self->dir;
    my $skip_re = $self->skip_re;
    my $pwd     = getcwd();

    my ( $dest, $src );
    unless ( ( $dest, $src ) = $l =~ m#\Asymlink from ~/(\S+) to \./(\S+)\z# )
    {
        die "wrong line <$l> in @{[$self->manifest]} !";
    }
    foreach my $str ( $src, $dest )
    {
        if ( $str =~ /([^a-zA-Z\-_0-9\.\/])/ )
        {
            die
"unacceptable character $1 in line <$l> in @{[$self->manifest]} !";
        }
        if ( $str =~ m%((?:\.\.)|(?:/\./)|(?:/.\z)|(?:\A-)|(?:/-))% )
        {
            die
"unacceptable sequence $1 in line <$l> in @{[$self->manifest]} !";
        }
    }
    chdir($dir);
    my $conf_dir = getcwd();
    my $h        = $ENV{HOME};
    if ( $dest =~ m#/# )
    {
        mkpath( [ "$h/" . dirname($dest) ] );
    }
    my $dd = "$h/$dest";
    my $ss = "$conf_dir/$src";
    print "Linking $dd to $ss\n";
    if ( -e $dd )
    {
        if ( ( !defined $skip_re ) or ( $dd !~ /$skip_re/ ) )
        {
            if ( not -l $dd )
            {
                die "$dd is not a symlink!";
            }
            elsif ( readlink($dd) ne $ss )
            {
                die "$dd does not point to $ss !";
            }
            elsif ( $ENV{V} )
            {
                warn "Not replacing $dd";
            }
        }
    }
    else
    {
        symlink( $ss, $dd );
    }
    chdir $pwd;

    return;
}

sub manifest_exists
{
    my $self = shift;

    return ( -f $self->manifest );
}

sub process_manifest
{
    my $self = shift;

    die "Manifest does not exist" if !$self->manifest_exists;

    open my $fh, "<", $self->manifest;
    while ( my $l = <$fh> )
    {
        chomp $l;
        $self->handle_line( { line => $l } );
    }
    close $fh;
    return 1;
}

1;

=head1 NAME

Symlink::DSL - a domain-specific language for setting up symbolic links.
