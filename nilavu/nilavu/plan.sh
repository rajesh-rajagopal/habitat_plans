
pkg_dirname=${pkg_distname}-${pkg_version}

pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_shasum=sha256sum
pkg_deps=()
pkg_build_deps=()
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)

pkg_name=nilavu
pkg_version=1.5.rc0
pkg_origin=megamio
pkg_maintainer="The Megam Maintainers <info@megam.io>"
pkg_license=('mit')
pkg_source=https://github.com/megamsys/nilavu/archive/${pkg_version}.tar.gz
pkg_shasum=de0536edc4cf1bde4d91207a605e3ed86ea106cc15c2c0262440892867b1d952

pkg_deps=(
  core/bundler
  core/cacerts
  core/glibc
  core/libffi
  core/libxml2
  core/libxslt
  core/libyaml
  core/node
  core/openssl
  core/postgresql
  core/ruby
  core/zlib
)

pkg_build_deps=(
  core/coreutils
  core/gcc
  core/make
)

pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_expose=(3000)

# The configure scripts for some RubyGems that build native extensions
# use `/usr/bin` paths for commands. This is not going to work in a
# studio where we don't have any of those commands. But we're kind of
# stuck because the native extension is going to be built during
# `bundle install`.
#
# We clean this link up in `do_install`.
do_prepare() {
  build_line "Setting link for /usr/bin/env to 'coreutils'"
  [[ ! -f /usr/bin/env ]] && ln -s $(pkg_path_for coreutils)/bin/env /usr/bin/env
  return 0
}

do_build() {
  export CPPFLAGS="${CPPFLAGS} ${CFLAGS}"

  local _bundler_dir=$(pkg_path_for bundler)
  local _libxml2_dir=$(pkg_path_for libxml2)
  local _libxslt_dir=$(pkg_path_for libxslt)
  local _postgresql_dir=$(pkg_path_for postgresql)
  local _pgconfig=$_postgresql_dir/bin/pg_config
  local _zlib_dir=$(pkg_path_for zlib)

  export GEM_HOME=${pkg_path}/vendor/bundle
  export GEM_PATH=${_bundler_dir}:${GEM_HOME}

  # don't let bundler split up the nokogiri config string (it breaks
  # the build), so specify it as an env var instead
  export NOKOGIRI_CONFIG="--use-system-libraries --with-zlib-dir=${_zlib_dir} --with-xslt-dir=${_libxslt_dir} --with-xml2-include=${_libxml2_dir}/include/libxml2 --with-xml2-lib=${_libxml2_dir}/lib"
  bundle config build.nokogiri '${NOKOGIRI_CONFIG}'
  bundle config build.pg --with-pg-config=${_pgconfig}

  # We need to add tzinfo-data to the Gemfile since we're not in an
  # environment that has this from the OS
  if [[ -z "`grep 'gem .*tzinfo-data.*' Gemfile`" ]]; then
    echo 'gem "tzinfo-data"' >> Gemfile
  fi

  # Remove the specific ruby version, because our ruby is 2.3
  sed -e 's/^ruby.*//' -i Gemfile

  bundle install --jobs 2 --retry 5 --path vendor/bundle --binstubs
}

do_install() {
  cp -R . ${pkg_prefix}/dist

  for binstub in ${pkg_prefix}/dist/bin/*; do
    build_line "Setting shebang for ${binstub} to 'ruby'"
    [[ -f $binstub ]] && sed -e "s#/usr/bin/env ruby#$(pkg_path_for ruby)/bin/ruby#" -i $binstub
  done

  if [[ `readlink /usr/bin/env` = "$(pkg_path_for coreutils)/bin/env" ]]; then
    build_line "Removing the symlink we created for '/usr/bin/env'"
    rm /usr/bin/env
  fi
}
