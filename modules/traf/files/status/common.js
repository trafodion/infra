// Copyright 2013 Hewlett-Packard
// Copyright 2013 OpenStack Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License. You may obtain
// a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.

function header(activeTabName) {
  tabsName = new Array();
  tabsLink = new Array();
  tabsName[0] = 'Downloads'; tabsLink[0] = 'http://traf-build.esgyn.com/';
  tabsName[1] = 'Trafodion Project'; tabsLink[1] = 'http://trafodion.incubator.apache.org';
  tabsName[2] = 'Trafodion Wiki'; tabsLink[2] = 'https://cwiki.apache.org/confluence/display/TRAFODION';

  document.write(
   '<div id="header" class="container">'+
   '<div class="span-5">'+
   ' <h1 id="logo"><a href="http://trafodion.incubator.apache.org/">Trafodion</a></h1>'+
   '</div>\n'+
   '<div class="span-19 last blueLine">'+
   '<div id="navigation" class="span-19">'+
   '<ul id="Menu1">\n')

  for (var i = 0; i < tabsName.length; i++) {
      document.write('<li><a id="menu-'+tabsName[i]+'" href="'+tabsLink[i]+'"')
      if (tabsName[i] == activeTabName) {
          document.write(' class="current"');
      }
      document.write('>'+tabsName[i]+'</a></li>\n');
  }

  document.write(
   '</ul>'+
   '</div>'+
   '</div>'+
   '</div>')
}

function footer() {
 document.write(
  '<div class="container">'+
  '<hr>'+
  '<div id="footer">'+
  '<div class="span-4">'+
  '<h3>Trafodion</h3>'+
  '<ul>'+
  ' <li><a href="https://trafodion.incubator.apache.org">Project</a></li>'+
  '</ul>'+
  '</div>\n'+
  '</div>'+
  '</div>')
}

