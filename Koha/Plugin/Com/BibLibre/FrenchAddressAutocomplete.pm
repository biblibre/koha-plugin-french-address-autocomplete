package Koha::Plugin::Com::BibLibre::FrenchAddressAutocomplete;

use Modern::Perl;
use utf8;

use base qw(Koha::Plugins::Base);

our $VERSION = '2.0';
our $APISRV='https://api-adresse.data.gouv.fr/search/?autocomplete=1&limit=15';
our $MAINADDRPREFIX='';
our @MAINADDRFIELDS=qw( address address2 city zipcode );
our $ALTADDRPREFIX='B_';
our @ALTADDRFIELDS=qw( address address2 city zipcode );
our $ALTCONTPREFIX='altcontact';
our @ALTCONTFIELDS=qw( address1 address2 city zipcode );

our $metadata = {
    name   => 'French Address Autocomplete',
    author => 'BibLibre',
    description => 'Help address/city/zipcode typing via french opendata API',
    date_authored   => '2021-08-16',
    date_updated    => '2026-02-10',
    minimum_version => '24.05',
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

# Mandatory even if does nothing
sub install {
    my ( $self, $args ) = @_;

    # Enable for main address
    foreach (@MAINADDRFIELDS) {
        next if $_ eq 'address2';
        my $enable_main_f = 'enable_'.$MAINADDRPREFIX.$_;
        $self->store_data({ $enable_main_f => 1 });
    }

    return 1;
}
 
# Mandatory even if does nothing
sub upgrade {
    my ( $self, $args ) = @_;
 
    return 1;
}
 
# Mandatory even if does nothing
sub uninstall {
    my ( $self, $args ) = @_;
 
    return 1;
}

# Options page.
sub configure {
    my ( $self, $args ) = @_;

    my $template = $self->get_template({ file => 'tmpl/config.tt' });
    my $query = $self->{'cgi'};
    my $op = $query->param('op') || '';

    if ($op eq 'cud-save') {
        foreach (@MAINADDRFIELDS) {
            my $enable_main_f = 'enable_'.$MAINADDRPREFIX.$_;
            my $value_main_f = $query->param($enable_main_f);
            $self->store_data({ $enable_main_f => $value_main_f });
        }
        foreach (@ALTADDRFIELDS) {
            my $enable_altaddr_f = 'enable_'.$ALTADDRPREFIX.$_;
            my $value_altaddr_f = $query->param($enable_altaddr_f);
            $self->store_data({ $enable_altaddr_f => $value_altaddr_f });
        }
        foreach (@ALTCONTFIELDS) {
            my $enable_altcont_f = 'enable_'.$ALTCONTPREFIX.$_;
            my $value_altcont_f = $query->param($enable_altcont_f);
            $self->store_data({ $enable_altcont_f => $value_altcont_f });
        }
    }

    foreach (@MAINADDRFIELDS) {
        my $enable_main_f = 'enable_'.$MAINADDRPREFIX.$_;
        my $value_main_f = $self->retrieve_data($enable_main_f);
        $template->param( $enable_main_f => $value_main_f );
    }
    foreach (@ALTADDRFIELDS) {
        my $enable_altaddr_f = 'enable_'.$ALTADDRPREFIX.$_;
        my $value_altaddr_f = $self->retrieve_data($enable_altaddr_f);
        $template->param( $enable_altaddr_f => $value_altaddr_f );
    }
    foreach (@ALTCONTFIELDS) {
        my $enable_altcont_f = 'enable_'.$ALTCONTPREFIX.$_;
        my $value_altcont_f = $self->retrieve_data($enable_altcont_f);
        $template->param( $enable_altcont_f => $value_altcont_f );
    }
    $template->param(
        mainaddrprefix => $MAINADDRPREFIX,
        mainaddrfields => \@MAINADDRFIELDS,
        altaddrprefix => $ALTADDRPREFIX,
        altaddrfields => \@ALTADDRFIELDS,
        altcontprefix => $ALTCONTPREFIX,
        altcontfields => \@ALTCONTFIELDS,
    );

    return $self->output_html( $template->output() );
}

sub intranet_js {
    my ( $self ) = @_;

    my $ret = q|
<script>
/*
 * Plugin French Address Autocomplete
 */
|;

    foreach (@MAINADDRFIELDS) {
        my $enable_main_f = 'enable_'.$MAINADDRPREFIX.$_;
        if ( $self->retrieve_data($enable_main_f) ){
            $ret .= _js_for_field($MAINADDRPREFIX, $_);
        }
    }
    foreach (@ALTADDRFIELDS) {
        my $enable_altaddr_f = 'enable_'.$ALTADDRPREFIX.$_;
        if ( $self->retrieve_data($enable_altaddr_f) ){
            $ret .= _js_for_field($ALTADDRPREFIX, $_);
        }
    }
    foreach (@ALTCONTFIELDS) {
        my $enable_altcont_f = 'enable_'.$ALTCONTPREFIX.$_;
        if ( $self->retrieve_data($enable_altcont_f) ){
            $ret .= _js_for_field($ALTCONTPREFIX, $_);
        }
    }

    $ret .= q|
</script>
|;
    return $ret;
}

sub _js_for_field {
    my $prefix = shift;
    my $field = shift;

    my $hint = q|<span class="hint" title="Saisie avec autocomplétion"> <i class="fa fa-magic"></i></span>|;
    my $js = qq|\$("input#"+"$prefix"+"$field").after('$hint');|;

    if ( $field eq 'zipcode' ) {
        $js .= qq|
\$("input#"+"$prefix"+"$field").autocomplete({
    minLength: 3,
    source: function (request, response) {
        \$.ajax({
            url: "$APISRV&type=municipality&q="+request.term,
            dataType: "json",
            success: function (data) {
                var postcodes = [];
                response(\$.map(data.features, function (item) {
                    // Ici on est obligé d'ajouter les CP dans un array pour ne pas avoir plusieurs fois le même
                    // mais un même CP peut correspondre à plusieurs villes.
                    var cle =  item.properties.postcode + " - " + item.properties.city;
                    if (\$.inArray(cle, postcodes) == -1) {
                        postcodes.push(cle);
                        return { label: cle,
                                city: item.properties.city,
                                value: item.properties.postcode
                        };
                    }
                }));
            }
        });
    },
    // On remplit aussi la ville
    select: function(event, ui) {
        \$("input#"+"$prefix"+"city").val(ui.item.city);
    }
});
|;
    } elsif ( $field eq 'city' ) {
        $js .= qq|
\$("input#"+"$prefix"+"$field").autocomplete({
    minLength: 3,
    source: function (request, response) {
        \$.ajax({
            url: "$APISRV&type=municipality&q="+request.term,
            dataType: "json",
            success: function (data) {
                var cities = [];
                response(\$.map(data.features, function (item) {
                    // Ici on est obligé d'ajouter les villes dans un array pour ne pas avoir plusieurs fois la même
                    if (\$.inArray(item.properties.postcode, cities) == -1) {
                        cities.push(item.properties.postcode);
                        return { label: item.properties.postcode + " - " + item.properties.city,
                                 postcode: item.properties.postcode,
                                 value: item.properties.city
                        };
                    }
                }));
            }
        });
    },
    // On remplit aussi le CP
    select: function(event, ui) {
        \$("input#"+"$prefix"+"zipcode").val(ui.item.postcode);
    }
});
|;
    } elsif ( $field =~ 'address' ) {
        $js .= qq|
\$("input#"+"$prefix"+"$field").autocomplete({
    minLength: 3,
    source: function (request, response) {
        \$.ajax({
            url: "$APISRV&q="+request.term+"&postcode="+\$("input#"+"$prefix"+"zipcode").val(),
            dataType: "json",
            success: function (data) {
                response(\$.map(data.features, function (item) {
                    return { label: item.properties.name, value: item.properties.name};
                }));
            }
        });
    }
});
|;
    }
    return $js;
}

1;
