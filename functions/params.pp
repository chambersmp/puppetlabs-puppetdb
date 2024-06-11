# @summary The puppetdb::params function is a custom backend for hiera. It generates a Hash of key:value pairs used by hiera. 
#   This function supports migration to hiera instead of the params.pp class pattern.
#
function puppetdb::params (
  Hash                  $options, # We ignore both of these arguments, but
  Puppet::LookupContext $context, # the function still needs to accept them.
) {

  $manage_pg_repo = if fact('os.family') =~ /RedHat|Debian/ {
    true
  } else {
    false
  }
  $puppetdb_version = 'present' # $puppetdb::globals::version
  $puppetdb_major_version = $puppetdb_version ? {
    'latest'  => '8',
    'present' => '8',
    default   => $puppetdb_version.split('.')[0],
  }

  if !($puppetdb_version in ['latest','present','absent']) and versioncmp($puppetdb_version, '3.0.0') < 0 {
    case fact('os.family') {
      'RedHat', 'Suse', 'Archlinux','Debian': {
        $puppetdb_package       = 'puppetdb'
        $terminus_package       = 'puppetdb-terminus'
        $etcdir                 = '/etc/puppetdb'
        $vardir                 = '/var/lib/puppetdb'
        # $puppet_confdir         = pick($puppetdb::globals::puppet_confdir,'/etc/puppet')
        $puppet_confdir         = '/etc/puppet'
        $puppet_service_name    = 'puppetmaster'
      }
      'OpenBSD': {
        $puppetdb_package       = 'puppetdb'
        $terminus_package       = 'puppetdb-terminus'
        $etcdir                 = '/etc/puppetdb'
        $vardir                 = '/var/db/puppetdb'
        # $puppet_confdir         = pick($puppetdb::globals::puppet_confdir,'/etc/puppet')
        $puppet_confdir         = '/etc/puppet'
        $puppet_service_name    = 'puppetmasterd'
      }
      'FreeBSD': {
        $puppetdb_package       = inline_epp('puppetdb<%= $puppetdb::params::puppetdb_major_version %>')
        $terminus_package       = inline_epp('puppetdb-terminus<%= $puppetdb::params::puppetdb_major_version %>')
        $etcdir                 = '/usr/local/etc/puppetdb'
        $vardir                 = '/var/db/puppetdb'
        # $puppet_confdir         = pick($puppetdb::globals::puppet_confdir,'/usr/local/etc/puppet')
        $puppet_confdir         = '/usr/local/etc/puppet'
        $puppet_service_name    = 'puppetmaster'
      }
      default: {
        fail("The fact 'os.family' is set to ${fact('os.family')} which is not supported by the puppetdb module.")
      }
    }
    $test_url         = '/v3/version'
  } else {
    case fact('os.family') {
      'RedHat', 'Suse', 'Archlinux','Debian': {
        $puppetdb_package    = 'puppetdb'
        $terminus_package    = 'puppetdb-termini'
        $etcdir              = '/etc/puppetlabs/puppetdb'
        # $puppet_confdir      = pick($puppetdb::globals::puppet_confdir,'/etc/puppetlabs/puppet')
        $puppet_confdir      = '/etc/puppetlabs/puppet'
        $puppet_service_name = 'puppetserver'
        $vardir              = '/opt/puppetlabs/server/data/puppetdb'
      }
      'OpenBSD': {
        $puppetdb_package    = 'puppetdb'
        $terminus_package    = 'puppetdb-termini'
        $etcdir              = '/etc/puppetlabs/puppetdb'
        # $puppet_confdir      = pick($puppetdb::globals::puppet_confdir,'/etc/puppetlabs/puppet')
        $puppet_confdir      = '/etc/puppetlabs/puppet'
        $puppet_service_name = undef
        $vardir              = '/opt/puppetlabs/server/data/puppetdb'
      }
      'FreeBSD': {
        $puppetdb_package    = inline_epp('puppetdb<%= $puppetdb::params::puppetdb_major_version %>')
        $terminus_package    = inline_epp('puppetdb-terminus<%= $puppetdb::params::puppetdb_major_version %>')
        $etcdir              = '/usr/local/etc/puppetdb'
        # $puppet_confdir      = pick($puppetdb::globals::puppet_confdir,'/usr/local/etc/puppet')
        $puppet_confdir      = '/usr/local/etc/puppet'
        $puppet_service_name = 'puppetserver'
        $vardir              = '/var/db/puppetdb'
      }
      default: {
        fail("The fact 'os.family' is set to ${fact('os.family')} which is not supported by the puppetdb module.")
      }
    }
    $test_url               = '/pdb/meta/v1/version'
  }

  $puppet_conf              = "${puppet_confdir}/puppet.conf"
  $confdir                  = "${etcdir}/conf.d"
  $ssl_dir                  = "${etcdir}/ssl"

  case fact('os.family') {
    'RedHat', 'Suse', 'Archlinux': {
      $puppetdb_user        = 'puppetdb'
      $puppetdb_group       = 'puppetdb'
      $puppetdb_initconf    = '/etc/sysconfig/puppetdb'
    }
    'Debian': {
      $puppetdb_user        = 'puppetdb'
      $puppetdb_group       = 'puppetdb'
      $puppetdb_initconf    = '/etc/default/puppetdb'
    }
    'OpenBSD': {
      $puppetdb_user        = '_puppetdb'
      $puppetdb_group       = '_puppetdb'
      $puppetdb_initconf    = undef
    }
    'FreeBSD': {
      $puppetdb_user        = 'puppetdb'
      $puppetdb_group       = 'puppetdb'
      $puppetdb_initconf    = undef
    }
    default: {
      fail("The fact 'os.family' is set to ${fact('os.family')} which is not supported by the puppetdb module.")
    }
  }
  $cleanup_timer_interval              = "*-*-* ${fqdn_rand(24)}:${fqdn_rand(60)}:00"
  $postgresql_ssl_folder               = "${puppet_confdir}/ssl"
  $postgresql_ssl_cert_path            = "${postgresql_ssl_folder}/certs/${trusted['certname']}.pem"
  $postgresql_ssl_key_path             = "${postgresql_ssl_folder}/private_keys/${trusted['certname']}.pem"
  $postgresql_ssl_ca_cert_path         = "${postgresql_ssl_folder}/certs/ca.pem"
  $ssl_cert_path                       = "${ssl_dir}/public.pem"
  $ssl_key_path                        = "${ssl_dir}/private.pem"
  $ssl_ca_cert_path                    = "${ssl_dir}/ca.pem"
  $certificate_whitelist_file          = "${etcdir}/certificate-whitelist"
  $database_max_pool_size_setting_name = if $puppetdb_version in ['latest','present'] or versioncmp($puppetdb_version, '4.0.0') >= 0 {
    'maximum-pool-size'
  } elsif versioncmp($puppetdb_version, '2.8.0') >= 0 {
    'partition-conn-max'
  } else {
    undef
  }

  $base_params = {
    # Keys have to start with the module's namespace, which in this case is `puppetdb::`.
    # Use key names that work with automatic class parameter lookup.
    'puppetdb::params::manage_pg_repo'                      => $manage_pg_repo,
    'puppetdb::params::puppetdb_major_version'              => $puppetdb_major_version,
    'puppetdb::params::puppetdb_package'                    => $puppetdb_package,
    'puppetdb::params::terminus_package'                    => $terminus_package,
    'puppetdb::params::etcdir'                              => $etcdir,
    'puppetdb::params::puppet_confdir'                      => $puppet_confdir,
    'puppetdb::params::puppet_conf'                         => $puppet_conf,
    'puppetdb::params::puppet_service_name'                 => $puppet_service_name,
    'puppetdb::params::vardir'                              => $vardir,
    'puppetdb::params::test_url'                            => $test_url,
    'puppetdb::params::confdir'                             => $confdir,
    'puppetdb::params::ssl_dir'                             => $ssl_dir,
    'puppetdb::params::puppetdb_user'                       => $puppetdb_user,
    'puppetdb::params::puppetdb_group'                      => $puppetdb_group,
    'puppetdb::params::puppetdb_initconf'                   => $puppetdb_initconf,
    'puppetdb::params::cleanup_timer_interval'              => $cleanup_timer_interval,
    'puppetdb::params::postgresql_ssl_folder'               => $postgresql_ssl_folder,
    'puppetdb::params::postgresql_ssl_cert_path'            => $postgresql_ssl_cert_path,
    'puppetdb::params::postgresql_ssl_key_path'             => $postgresql_ssl_key_path,
    'puppetdb::params::postgresql_ssl_ca_cert_path'         => $postgresql_ssl_ca_cert_path,
    'puppetdb::params::ssl_cert_path'                       => $ssl_cert_path,
    'puppetdb::params::ssl_key_path'                        => $ssl_key_path,
    'puppetdb::params::ssl_ca_cert_path'                    => $ssl_ca_cert_path,
    'puppetdb::params::certificate_whitelist_file'          => $certificate_whitelist_file,
    'puppetdb::params::database_max_pool_size_setting_name' => $database_max_pool_size_setting_name,
  }

# $base_params = {
  # 'puppetdb::manage_pg_repo'                      => $manage_pg_repo,
  # 'puppetdb::puppetdb_major_version'              => $puppetdb_major_version,
  # 'puppetdb::puppetdb_package'                    => $puppetdb_package,
  # 'puppetdb::terminus_package'                    => $terminus_package,
  # 'puppetdb::etcdir'                              => $etcdir,
  # 'puppetdb::puppet_confdir'                      => $puppet_confdir,
  # 'puppetdb::puppet_conf'                         => $puppet_conf,
  # 'puppetdb::puppet_service_name'                 => $puppet_service_name,
  # 'puppetdb::vardir'                              => $vardir,
  # 'puppetdb::test_url'                            => $test_url,
  # 'puppetdb::confdir'                             => $confdir,
  # 'puppetdb::ssl_dir'                             => $ssl_dir,
  # 'puppetdb::puppetdb_user'                       => $puppetdb_user,
  # 'puppetdb::puppetdb_group'                      => $puppetdb_group,
  # 'puppetdb::puppetdb_initconf'                   => $puppetdb_initconf,
  # 'puppetdb::cleanup_timer_interval'              => $cleanup_timer_interval,
  # 'puppetdb::postgresql_ssl_folder'               => $postgresql_ssl_folder,
  # 'puppetdb::postgresql_ssl_cert_path'            => $postgresql_ssl_cert_path,
  # 'puppetdb::postgresql_ssl_key_path'             => $postgresql_ssl_key_path,
  # 'puppetdb::postgresql_ssl_ca_cert_path'         => $postgresql_ssl_ca_cert_path,
  # 'puppetdb::ssl_cert_path'                       => $ssl_cert_path,
  # 'puppetdb::ssl_key_path'                        => $ssl_key_path,
  # 'puppetdb::ssl_ca_cert_path'                    => $ssl_ca_cert_path,
  # 'puppetdb::certificate_whitelist_file'          => $certificate_whitelist_file,
  # 'puppetdb::database_max_pool_size_setting_name' => $database_max_pool_size_setting_name,
# #   Keys have to start with the module's namespace, which in this case is `puppetdb::`.
# #   Use key names that work with automatic class parameter lookup. This
# #   key corresponds to the `puppetdb` class's `$service_name` parameter.
# }

  $os_params = case $facts['os']['family'] {
    # 'Debian': {
    #   {
    #     'puppetdb::manage_pg_repo' => true,
    #   }
    # }
    # 'RedHat': {
    #   {
    #     'puppetdb::manage_pg_repo' => true,
    #   }
    # }
    default: {
      {
        # 'puppetdb::manage_pg_repo' => false,
      }
    }
  }

  # Merge the hashes, overriding the service name if this platform uses a non-standard one:
  $base_params + $os_params
}
