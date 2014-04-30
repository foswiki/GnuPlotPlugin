# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2010-2014 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
package Foswiki::Plugins::GnuPlotPlugin;

use strict;
use warnings;

our $VERSION = '2.00';
our $RELEASE = '2.00';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

our $SHORTDESCRIPTION = 'Allows users to plot data and functions using <nop>GnuPlot';

sub core {
  unless ($core) {
    require Foswiki::Plugins::GnuPlotPlugin::Core;
    $core = new Foswiki::Plugins::GnuPlotPlugin::Core();
  }  

  return $core;
}

sub initPlugin {

  Foswiki::Func::registerTagHandler('GNUPLOT', sub {
    core->handleGnuPlotTag(@_);
  });

  return 1;
}

sub beforeSaveHandler {
  core->beforeSaveHandler(@_);
}


1;
