{% from 'atlassian-crowd/map.jinja' import crowd with context %}

include:
  - java

crowd-dependencies:
  pkg.installed:
    - pkgs:
      - libxslt

crowd:
  file.managed:
    - name: /etc/systemd/system/atlassian-crowd.service
    - source: salt://atlassian-crowd/files/atlassian-crowd.service
    - template: jinja
    - defaults:
        config: {{ crowd }}

  module.wait:
    - name: service.systemctl_reload
    - watch:
      - file: crowd

  group.present:
    - name: {{ crowd.group }}

  user.present:
    - name: {{ crowd.user }}
    - home: {{ crowd.dirs.home }}
    - gid: {{ crowd.group }}
    - require:
      - group: crowd
      - file: crowd-dir

  service.running:
    - name: atlassian-crowd
    - enable: True
    - require:
      - file: crowd

crowd-graceful-down:
  service.dead:
    - name: atlassian-crowd
    - require:
      - module: crowd
    - prereq:
      - file: crowd-install

{% if crowd.download %}
crowd-download:
  cmd.run:
    - name: "curl -L --silent '{{ crowd.url }}' > '{{ crowd.source }}'"
    - unless: "test -f '{{ crowd.source }}'"
{% endif %}

crowd-install:
  archive.extracted:
    - name: {{ crowd.dirs.extract }}
    - source: {{ crowd.source }}
    - options: z
    - list_options: gzip -d -c
    - if_missing: {{ crowd.dirs.current_install }}
    - user: root
    - group: root
    - keep: True
    - require:
      - file: crowd-extractdir
      - cmd: crowd-download

  file.symlink:
    - name: {{ crowd.dirs.install }}
    - target: {{ crowd.dirs.current_install }}
    - require:
      - file: crowd-dir
      - archive: crowd-install
    - watch_in:
      - service: crowd

crowd-server-xsl:
  file.managed:
    - name: /tmp/crowd-server.xsl
    - source: salt://atlassian-crowd/files/server.xsl
    - template: jinja
    - require:
      - file: crowd-install

  cmd.run:
    - name: 'xsltproc --stringparam pHttpPort "{{ crowd.get('http_port', '') }}" --stringparam pHttpScheme "{{ crowd.get('http_scheme', '') }}" --stringparam pHttpProxyName "{{ crowd.get('http_proxyName', '') }}" --stringparam pHttpProxyPort "{{ crowd.get('http_proxyPort', '') }}" --stringparam pAjpPort "{{ crowd.get('ajp_port', '') }}" -o /tmp/crowd-server.xml /tmp/crowd-server.xsl server.xml'
    - cwd: {{ crowd.dirs.install }}/apache-tomcat/conf
    - require:
      - file: crowd-server-xsl

crowd-server-xml:
  file.managed:
    - name: {{ crowd.dirs.install }}/apache-tomcat/conf/server.xml
    - source: /tmp/crowd-server.xml
    - require:
      - cmd: crowd-server-xsl
    - watch_in:
      - service: crowd

crowd-dir:
  file.directory:
    - name: {{ crowd.dir }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

crowd-home:
  file.directory:
    - name: {{ crowd.dirs.home }}
    - user: {{ crowd.user }}
    - group: {{ crowd.group }}
    - mode: 755
    - makedirs: True

crowd-extractdir:
  file.directory:
    - name: {{ crowd.dirs.extract }}
    - use:
      - file: crowd-dir

crowd-scriptdir:
  file.directory:
    - name: {{ crowd.dirs.scripts }}
    - use:
      - file: crowd-dir

{% for file in [ 'env.sh', 'start.sh', 'stop.sh' ] %}
crowd-script-{{ file }}:
  file.managed:
    - name: {{ crowd.dirs.scripts }}/{{ file }}
    - source: salt://atlassian-crowd/files/{{ file }}
    - user: {{ crowd.user }}
    - group: {{ crowd.group }}
    - mode: 755
    - template: jinja
    - defaults:
        config: {{ crowd }}
    - require:
      - file: crowd-scriptdir
    - watch_in:
      - service: crowd
{% endfor %}

{% for chmodfile in ['start_crowd.sh', 'stop_crowd.sh'] %}
crowd-permission-{{ chmodfile }}:
  file.managed:
    - name: {{ crowd.dirs.install }}/{{ chmodfile }}
    - user: {{ crowd.user }}
    - group: {{ crowd.group }}
    - replace: False
    - require:
      - file: crowd-install
    - require_in:
      - service: crowd
{% endfor %}

{% for chmoddir in ['bin', 'work', 'temp', 'logs'] %}
crowd-permission-{{ chmoddir }}:
  file.directory:
    - name: {{ crowd.dirs.install }}/apache-tomcat/{{ chmoddir }}
    - user: {{ crowd.user }}
    - group: {{ crowd.group }}
    - recurse:
      - user
      - group
    - require:
      - file: crowd-install
    - require_in:
      - service: crowd
{% endfor %}
