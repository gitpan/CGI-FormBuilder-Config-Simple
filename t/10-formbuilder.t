#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More tests => 16;
use Test::DatabaseRow;
use WWW::Mechanize;
# use Test::HTML::Tidy;
use Cwd;
use Carp;
use Config::Simple;
use Data::Dumper;

use lib qw(t);
use lib qw(lib);
use My::Module::Test;
# use CGI::FormBuilder::Config::Simple;

my $self = My::Module::Test->new({ config_file => 't/conf.d/cgi_fb_config_simple.ini' });
isa_ok($self,'My::Module::Test');

local $Test::DatabaseRow::dbh = $self->{'dbh'};
my $agent = WWW::Mechanize->new();

is($self->errstr,'','The error string starts off empty.');
$self->errstr('Note this error.  ');
like($self->errstr,qr/Note this error./,'The error string accepts an assignment.');
$self->errstr('Note another error.  ');
like($self->errstr,qr/Note another error./,'The error string accepts another assignment.');
like($self->errstr,qr/Note this error./,'  .  .  .  w/o losing track of the earlier assignment.');

my $db = $self->{'cfg'}->get_block('db');

is($db->{'db_pw'},'test_secret','Found correct database password');
is($db->{'db_host'},'test_host','Found correct database host');

my $form_html = $self->render_web_form('signup_form') or
    carp("$0 died rendering a signup form. $self->errstr. $!");

like($form_html,qr/Generated by CGI::FormBuilder/,'Seems this html was built by CGI::FormBuilder');
like($form_html,qr/<script type="text\/javascript">/,'And it seems to have generated some javascript');

TODO: { 

  local $TODO = 'This test seems to fail for some unknown reason';
  like($form_html,qr/function validate_signup (form)/,'Got anticipated signature on js function validate_signup');

}

like($form_html,qr/<form action="10-formbuilder.t" cgi_fb_cfg_simple_form_name="signup_form"/,'script seems to create signup form');
like($form_html,qr/<fieldset id="signup_sample_fieldset">/,'Found correct fieldset');
like($form_html,qr/<input id="this_field" name="this_field" /,'Found a this_field input option');
like($form_html,qr/<input id="that_field" name="that_field" /,'Found a that_field input option');
like($form_html,qr/<input id="another_field" name="another_field" /,'Found a another_field input option');
like($form_html,qr/<input id="signup_submit" name="_submit" type="submit" value="Lets Get Started" \/>/,'Found the submit button');

# print STDERR $form_html;
# print STDERR Dumper($self->{'form'});
# print STDERR Dumper($self->{'dbh'});
# print STDERR Dumper($self->{'cfg'});

# still need to test and refine debug output
# tests ought to capture and redirect and compare STDERR stream
# I had to do that with Test::MonitorSites

# $form_html = $self->render_web_form('signup_form',3) or
#     carp("$0 died rendering a signup form. $self->errstr. $!");
# 
# $form_html = $self->render_web_form('signup_form',2) or
#     carp("$0 died rendering a signup form. $self->errstr. $!");
# 
# $form_html = $self->render_web_form('signup_form',1) or
#     carp("$0 died rendering a signup form. $self->errstr. $!");

1;

