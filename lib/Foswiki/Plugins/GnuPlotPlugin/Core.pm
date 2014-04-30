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
package Foswiki::Plugins::GnuPlotPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox ();
use Foswiki::Plugins ();
use File::Temp ();
use Assert;

sub new {
  my $class = shift;

  my $this = {
    debug => $Foswiki::cfg{GnuPlotPlugin}{Debug},
    gnuPlotCmd => $Foswiki::cfg{GnuPlotPlugin}{GnuPlotCmd} || '/usr/bin/gnuplot %INFILE|F%',
    @_
  };

  bless($this, $class);

  return $this;
}

sub writeDebug {
  my ($this, $msg) = @_;

  return unless $this->{debug};

  Foswiki::Func::writeDebug("GnuPlotPlugin::Core - ".$msg);
}

sub inlineError {
  my $error = shift;

  return "<div class='foswikiAlert'>ERROR: $error</div>";
}

sub handleGnuPlotTag {
  my ($this, $session, $params, $topic, $web) = @_;

  my $name = $params->{_DEFAULT};
  return inlineError("a plot must have a name") unless $name;

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $params->{topic})
    if $params->{topic};

  my $data = '';
  my $mode = $params->{mode} || 'attachment';

  if ($mode eq 'section') {
    $data = $this->getDataFromSection($web, $topic, $params);
  } elsif ($mode eq 'attachment') {
    $data = $this->getDataFromAttachment($web, $topic, $params);
  } else {
    return inlineError("unknown mode '$mode'");
  }

  my $fileType = $params->{type} || 'png';
  # TODO: sanitize fileType

  my $outFile = $this->getPath($web, $topic, $name . '.'. $fileType);

  my $width = $params->{width} || 640;
  $width =~ s/[^\d\.]//g;

  my $height = $params->{height} || 480;
  $height =~ s/[^\d\.]//g;

  $data = $this->expandCommonVariables($web, $topic, $data);
  $data = <<"HERE" . $data;
set terminal $fileType size $width,$height
set output "$outFile"
HERE

  $this->writeDebug("data=".$data);

  my $tmpFile = new File::Temp(SUFFIX => '.gnu', UNLINK => ($this->{debug}? 0 : 1));
  my $tmpFileName = $tmpFile->filename;
  Foswiki::Func::saveFile($tmpFileName, $data);

  $this->writeDebug("tmpFile=".$tmpFileName);

  my $gnuplotCmd = $this->{gnuPlotCmd};
  $this->writeDebug("gnuPlotCmd=$gnuplotCmd");
 
  my ($output, $status, $error) = Foswiki::Sandbox->sysCommand(
    $gnuplotCmd,
    INFILE => $tmpFileName,
  );

  $this->writeDebug("output=$output, status=$status, error=$error");

  my $result = '';
  unless ($error) {
    $result = "<img src='%PUBURLPATH%/$web/$topic/$name.$fileType' class='gnuPlotImage' id='gnuplot$name' alt='$name' width='$width' height='$height' />";
  } else {

    $error =~ s/^".*", line (\d+)/$name, line $1/gm;
    $result = "<div class='foswikiAlert'>ERROR: while rendering plot:</div>\n<verbatim>$error</verbatim>";
  }

  return $result;
}

sub getDataFromAttachment {
  my ($this, $web, $topic, $params) = @_;

  my $attachment = $this->sanitizeFileName($params->{_DEFAULT});
  $attachment .= '.gnu' unless $attachment =~ /\.\w+$/;

  throw Error::Simple("attachment does not exist '$attachment'")
    unless Foswiki::Func::attachmentExists($web, $topic, $attachment);

  return Foswiki::Func::readAttachment($web, $topic, $attachment);
}

sub getDataFromSection {
  my ($this, $web, $topic, $params) = @_;

  my $session = $Foswiki::Plugins::SESSION;
  my $section = $params->{_DEFAULT} || $params->{section};

  $this->writeDebug("getDataFromSection($web, $topic, $section");

  $params->{_DEFAULT} = "$web.$topic";
  $params->{section} = $section;
  
  my ($obj) = Foswiki::Func::readTopic($web, $topic);
  my $result = $session->INCLUDE($params, $obj);

  return $result;
}

sub expandCommonVariables {
  my ($this, $web, $topic, $data) = @_;

  $data = Foswiki::Func::expandCommonVariables($data, $topic, $web);

  # remove some stuff for security reasons
  $data =~ s/^\s*set\s+term(inal)?.*$//gm;
  $data =~ s/^\s*set\s+out(put)?.*$//gm;

  # some extras 
  my $attachDir = $this->getPath($web, $topic);
  my $pubDir = Foswiki::Func::getPubDir();
  $data =~ s/\%ATTACHDIR\%/$attachDir/g;
  $data =~ s/\%PUBDIR\%/$pubDir/g;

  return $data;
}

sub sanitizeFileName {
  my ($this, $fileName) = @_;

  $fileName =~ s{[\\/]+$}{};
  $fileName =~ s!^.*[\\/]!!;
  $fileName =~ s/$Foswiki::regex{filenameInvalidCharRegex}//go;

  return $fileName;
}

sub getPath {
  my ($this, $web, $topic, $attachment) = @_;

  $web =~ s/\./\//g;

  my $path = Foswiki::Func::getPubDir().'/'.$web.'/'.$topic;

  File::Path::mkpath($path) unless -d $path;

  $path .= '/'.$attachment if defined $attachment;

  return $path;
}


1;

