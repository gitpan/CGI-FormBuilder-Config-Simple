package CGI::FormBuilder::Config::Simple;

use warnings;
use strict;
use Carp;
use Data::Dumper;
use CGI::FormBuilder;

=head1 NAME

CGI::FormBuilder::Config::Simple - deploy web forms w/ .ini file  

=head1 VERSION

Version 0.07

=cut

our $VERSION = '0.07';


=head1 SYNOPSIS

This module exists to synthesize the abstractions of
CGI::FormBuilder with those of Config::Simple to make it nearly
possible to deploy a working form and database application
by simply configuring an ini file.  Add to that config file
your data processing routines, perhaps a template from the
design team and you are done.  This module handles converting
a config file into a form, validating user input and all that.

A developer would still be required to write methods to process
their data, but much of the rest of the work will be covered
by this modules' methods, and those of the ones just cited.

For some sample code, please see:
	t/My/Module/Test.pm
which provides scaffolding for the test suite.

    -- signup.cgi --

    use lib qw(lib);
    use MyModule::Signup;
        # see below for details . . . 

    my $debug_level = 0; # raise to 3 for noisy logs 
    my $signup = MyModule::Signup->new({ config_file => '/path/to/config/file.ini' });
        # should create a config object respecting ->param() method 
        # and embed that object at $self->{'cfg'}
    my $signup_form_html = $signup->render_web_form('sign_up',$debug_level) or
        carp("$0 died rendering a signup form. $signup->errstr. $!");

    1;

    -- /lib/MyModule/Signup.pm -- 

    package MyModule::Signup;

    use base 'CGI::FormBuilder::Config::Simple';

    sub new {
      my $class = shift;
      my $defaults = shift;
      my $self = {};

      $self->{'cfg'} = Config::Simple::Extended->new(
            { filename => $defaults->{'config_file'} } );
            # or use its ->inherit() method to overload configurations 

      my $db = $self->{'cfg'}->get_block('db');
      $self->{'dbh'} = MyModule::DB->connect($db);
            # a DBI->connect() object

      # whatever else you need in your constructor

      bless $self, $class;
      return $self;
    }

    # plus additional methods to process collected data,
    # but the code above should render and validate your data 

    # Now write a config file looking like this, and your are done

    -- conf.d/apps.example.com/signup_form.ini --

    [db]
       . . . 


    [signup_form]
    
    template=/home/webapps/signup/conf.d/apps.example.com/tmpl/signup_form.tmpl.html
    fieldsets=sample_fieldset
    title='Signup Form'
    submit='Lets Get Started'
    header=1
    name='signup'
    method='post'
    debug=0
    # debug = 0 | 1 | 2 | 3
    reset=1
    fieldsubs=1
    keepextras=1

    ;action=$script
    ;values=\%hash | \@array
    ;validate=\%hash
    ;required=[qw()]

    [signup_form_sample_fieldset]
    fields=this_field,that_field,another_field
    process_protocol=sample_data_processing_method
    enabled=1
    
    [signup_form_sample_fieldset_this_field]
    name=this_field
    label='This field'
    type=text
    fieldset=sample_fieldset
    require=1
    validate='/\w+/'
    
    [signup_form_sample_fieldset_that_field]
       . . . 
    
    [signup_form_sample_fieldset_another_field]
       . . . 

=head1 METHODS 

=head2 ->render_web_form('form_name',$debug_level)

Given an object, with a configuration object accessible at
$self->{'cfg'}, honoring the ->param() method provided by
Config::Simple and Config::Simple::Extended (but possibly
others), render the html for a web form for service.

This method takes an option second argument, used to set
the debug level.  Use 0 or undefined for quiet operation,
1 or greater to see information about the form being built,
2 or greater to watch the field sets being built and 3 or
greater to watch the fields being built.

=cut

sub render_web_form {
  my $self = shift;
  my $form_name = shift;
  my $debug = shift || 0;

  my $form_attributes = $self->{'cfg'}->get_block("$form_name");
  my %attributes;
  foreach my $attribute (keys %{$form_attributes}){
    my $value = $form_attributes->{$attribute};
    $attributes{$attribute} = $value;
  }
  my $form = CGI::FormBuilder->new( %attributes );
  $form->{'cgi_fb_cfg_simple_form_name'} = $form_name;
  if($debug > 0){
    print STDERR Dumper(\%attributes);
  }
  # print STDERR Dumper($form);

  my $html;
  my $fieldsets = $self->{'cfg'}->param("$form_name.fieldsets");
  my @fieldsets = split /,/,$fieldsets;

  # print Dumper(\@fieldsets);
  foreach my $fieldset (@fieldsets) {
    if($debug > 1){
      print STDERR "Now building fieldset: " . Dumper($fieldset) . "\n";
    }
    $self->build_fieldset($form,$fieldset,$debug);
  }
  if ($form->submitted && $form->validate) {
    # Do something to update your data (you would write this)
    $self->process_form($form);

    # Show confirmation screen
    $html = $form->confirm(header => 1);
  } else {
    # Print out the form
    $html = $form->render(header => 1);
  }

  $self->{'form'} = $form;
  return $html;
}

=head2 $self->process_form($form)

In your My::Module, you need to write a method for every
fieldset.process_protocol in the configuration file.

This method will be called by the ->render_web_form() method
and cycle through each fieldset and execute your application
specific database interactions and other required processing.

=cut 

sub process_form {
  my $self = shift;
  my $form = shift;
  my $field = $form->fields;
  my $form_name = $form->{'cgi_fb_cfg_simple_form_name'};

  # print STDERR Dumper($field);

  my $fieldsets = $self->{'cfg'}->param("$form_name.fieldsets");
  my @fieldsets = split /,/,$fieldsets;

  foreach my $fieldset (@fieldsets) {
    my $stanza = $form_name . '_' . $fieldset;
    my $process_protocol = $self->{'cfg'}->param("$stanza.process_protocol");
    # print STDERR "Our process_protocol is: $process_protocol \n";
    $self->$process_protocol($form_name,$field);
  }

  return;
}

=head2 $self->build_fieldset($form,$fieldset,$debug_level)

Parses the configuration object for the fields required to
build a form's fieldset and calls ->build_field() to compile the
pieces necessary to configure the CGI::FormBuilder $form object.

=cut

sub build_fieldset {
  my $self = shift;
  my $form = shift;
  my $fieldset = shift;
  my $debug = shift;

  # print STDERR "Now being asked to build a fieldset \n";
  my $form_name = $form->{'cgi_fb_cfg_simple_form_name'};
  my $stanza = $form_name . '_' . $fieldset;
  if($debug > 1){
    print STDERR "->build_fieldset() now processing $stanza \n";
  }
  if($self->{'cfg'}->param("$stanza.enabled")){
    my $stanza = $form_name . '_' . $fieldset;
    my $fields = $self->{'cfg'}->param("$stanza.fields");
    foreach my $field (@{$fields}) {
      my $field_stanza = $stanza . '_' . $field;
      if($debug > 1){
        print STDERR "seeking field stanza: $field_stanza \n";
      }
      unless($self->{'cfg'}->param("$field_stanza.disabled")){
        # print STDERR Dumper($field),"\n";
        $self->build_field($form,$fieldset,$field,$debug);
      }
    }
  } else {
    print STDERR "The $fieldset fieldset has not been enabled \n";
  }
  return;
}

=head2 $self->build_field($form,$fieldset,$field)

Parses the configuration object for the attributes used to
configure a CGI::FormBuilder->field() object.

=cut

sub build_field {
  my $self = shift;
  my $form = shift;
  my $fieldset = shift;
  my $field = shift;
  my $debug = shift;

  my $form_name = $form->{'cgi_fb_cfg_simple_form_name'};
  my $block = $form_name . '_' . $fieldset . '_' . $field;
  if($debug > 2){
    print STDERR "Our next block is: $block \n";
  }
  my $field_attributes = $self->{'cfg'}->get_block($block);

  my @attributes;
  foreach my $attribute (keys %{$field_attributes}){
    if($debug > 2){
      print STDERR "My attribute is: $attribute \n";
    }
    my $value = $field_attributes->{$attribute};
    # if($attribute eq 'name'){ $value = $fielddset . '_' . $value;}
    push @attributes, $attribute => $value;
  }

  $form->field(@attributes);
  return;
}

=head2 errstr('Error description')

Append its argument, if any, to the error string, and return
the result.

=cut

sub errstr {
  my $self = shift;
  my $error = shift || '';
  $self->{'errstr'} .= $error if(defined($error));
  return $self->{'errstr'};
}

=head1 AUTHOR

Hugh Esco, C<< <hesco at campaignfoundations.com> >>

=head1 BUGS

Please report any bugs or feature requests
to C<bug-cgi-formbuilder-config-simple
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CGI-FormBuilder-Config-Simple>.
I will be notified, and then you'll automatically be notified
of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CGI::FormBuilder::Config::Simple


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CGI-FormBuilder-Config-Simple>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CGI-FormBuilder-Config-Simple>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CGI-FormBuilder-Config-Simple>

=item * Search CPAN

L<http://search.cpan.org/dist/CGI-FormBuilder-Config-Simple/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010 Hugh Esco.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


=cut

1; # End of CGI::FormBuilder::Config::Simple
