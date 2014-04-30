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
use Digest::MD5 ();
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

  my $type = $params->{type} || 'png';

  # TODO: support canvas
  if ($type =~ /^(gif|jpeg|png|svg)$/) {
    $type = $1;
  } else {
    return inlineError("unsupported type '$type'");
  }

  my $width = $params->{width} || 640;
  $width =~ s/[^\d\.]//g;

  my $height = $params->{height} || 480;
  $height =~ s/[^\d\.]//g;

  my $size = $params->{size};
  if (defined $size) {
    if ($size =~ /^(\d+)x(\d+)$/) {
      $width = $1;
      $height = $1;
    } elsif ($type eq 'svg' && $size eq 'fixed') {
      $size = "$width,$height $size";
    } elsif ($type eq 'svg' && $size eq 'dynamic') {
      $size = "$width,$height $size";
      $width = 'auto';
      $height = 'auto';
    } else {
      return inlineError("invalid size parameter '$size'");
    }
  } else {
    $size = "$width,$height";
    $size .= " dynamic" if $type eq 'svg';
  }

  $data = $this->expandCommonVariables($web, $topic, $data);

  my $digest = Digest::MD5::md5_hex($data, $name, $size);
  my $outFile = $this->getImageName($name, $digest, $type);

  my $request = Foswiki::Func::getRequestObject();
  my $refresh = $request->param("refresh") || '';
  $refresh = ($refresh =~ /^(on|gnuplot|image)$/ ? 1:0);

  $this->writeDebug("doing a refresh") if $refresh;

  if (!$refresh && Foswiki::Func::attachmentExists($web, $topic, $outFile)) {
    $this->writeDebug("already found $outFile at $web.$topic ... not generating again");
  } else {
    my $outPath = File::Temp->new(UNLINK => ($this->{debug}?0:1));
    
    $this->writeDebug("plotting to $outPath");
    $data = <<"HERE" . $data;
set terminal $type size $size
set output "$outPath"
HERE

    $this->writeDebug("data=".$data);

    my $tmpFile = File::Temp->new(SUFFIX => '.gnu', UNLINK => ($this->{debug}? 0 : 1));
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

    if ($error) {
      $error =~ s/^".*", line (\d+)/$name, line $1/gm;
      return inlineError("can't rendering plot:\n<verbatim>$error</verbatim>");
    } 

    my $size = (stat($outPath))[7];
    $this->writeDebug("size=$size");

    # attach
    my $wikiName = Foswiki::Func::getWikiName();
    if (Foswiki::Func::checkAccessPermission("CHANGE", $wikiName, undef, $topic, $web)) {
      Foswiki::Func::saveAttachment($web, $topic, $outFile, { 
        file => $outPath,
        filesize => $size,
        minor => 1,
        dontlog => 1,
        comment => 'Auto-attached by GnuPlotPlugin',
      });
    } else {
      return inlineError("can't generate plot: access denied to attach output to $web.$topic");
    };
  }

  # TODO: need a differnt template for type=canvas
  return "<img src='%PUBURLPATH%/$web/$topic/$outFile' class='gnuPlotImage' id='gnuplot$name' alt='$name' width='$width' height='$height' />";
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
  my $pubDir = $Foswiki::cfg{PubDir};
  my $attachDir = $pubDir . '/' . $web . '/' . $topic;
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

sub getImageName {
  my ($this, $name, $digest, $type) = @_;

  return 'gnuplot_'.$digest.'_'.$name.'.'.$type;
}

sub deleteImages {
  my ($this, $web, $topic, $include) = @_;

}

sub beforeSaveHandler {
  my ($this, undef, $topic, $web, $meta) = @_;

  $this->writeDebug("called beforeSaveHandler($web, $topic)");
  
  my $it = $meta->eachAttachment();
  while ($it->hasNext()) {
    my $file = $it->next();
    if ($file =~ /^(gnuplot_[0-9a-f]{32}.*)$/) {
      $file = $1;
      $this->writeDebug("deleting $file from $web.$topic");
      $meta->remove('FILEATTACHMENT', $file);
      $meta->removeFromStore($file);
    }
  }
}

1;

