package Koha::Plugin::Com::BibLibre::FrenchAddressAutocomplete;

use Modern::Perl;
use utf8;

use base qw(Koha::Plugins::Base);

our $VERSION = '1.0';
our $APISRV='https://api-adresse.data.gouv.fr/search/';

our $metadata = {
    name   => 'French Address Autocomplete',
    author => 'BibLibre',
    description => 'Help address/city/zipcode typing via french opendata API',
    date_authored   => '2021-08-16',
    date_updated    => '2021-08-16',
    minimum_version => '19.11',
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

sub intranet_js {
    my ( $self ) = @_;

    my $ret = q|
<script>
/*
 * Plugin French Address Autocomplete
 */
|;

    # Main address
    $ret .= _js_for_field('', 'zipcode');
    $ret .= _js_for_field('', 'city');
    $ret .= _js_for_field('', 'address');
    # Alternate address
    $ret .= _js_for_field('B_', 'zipcode');
    $ret .= _js_for_field('B_', 'city');
    $ret .= _js_for_field('B_', 'address');
    # Alternate contact
    $ret .= _js_for_field('altcontact', 'zipcode');
    $ret .= _js_for_field('altcontact', 'city');
    $ret .= _js_for_field('altcontact', 'address1');

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
    source: function (request, response) {
        \$.ajax({
            url: "$APISRV?autocomplete=1&type=municipality&q="+request.term,
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
    source: function (request, response) {
        \$.ajax({
            url: "$APISRV?autocomplete=1&type=municipality&q="+request.term,
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
    source: function (request, response) {
        \$.ajax({
            url: "$APISRV?autocomplete=1&q="+request.term+"&postcode="+\$("input#"+"$prefix"+"zipcode").val(),
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
