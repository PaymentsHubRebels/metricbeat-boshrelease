require 'rspec'
require 'yaml'
require 'json'
require 'bosh/template/test'

describe 'metricbeat job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../..')) }
  let(:job) { release.job('metricbeat') }
  
  let(:kafka_link) {
    Bosh::Template::Test::Link.new(
      name: 'kafka',
      instances: [
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.1'),
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.2'),
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.3')
      ]
    )
  }

  let(:zookeeper_link) {
    Bosh::Template::Test::Link.new(
      name: 'zookeeper',
      instances: [
        Bosh::Template::Test::LinkInstance.new(address: '10.0.1.1'),
        Bosh::Template::Test::LinkInstance.new(address: '10.0.1.2'),
        Bosh::Template::Test::LinkInstance.new(address: '10.0.1.3')
      ]
    )
  }

  let(:elasticsearch_link) {
    Bosh::Template::Test::Link.new(
      name: 'elasticsearch',
      instances: [
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.10'),
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.20'),
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.30')
      ]
    )
  }

  let(:kibana_link) {
    Bosh::Template::Test::Link.new(
      name: 'kibana',
      instances: [
        Bosh::Template::Test::LinkInstance.new(address: '10.0.0.50')
      ]
    )
  }

  let(:redis_link) {
    Bosh::Template::Test::Link.new(
      name: 'redis',
      instances: [
        Bosh::Template::Test::LinkInstance.new(address: '1.2.3.4')
      ],
      properties: {
        'password' => 'asdf1234',
        'port' => 4321,
        'base_dir' => '/redis'
      }
    )
  }

  describe 'metricbeat.yml' do
    let(:template) { job.template('config/metricbeat.yml') }

    it 'configures the shipper name properly when specified in properties' do 
      config = YAML.load(template.render(
        {
          'metricbeat' => {
            'elasticsearch' => {
              'port' => 1234
            },
            'name' => 'test_name'
          } 
        },
        consumes: []
      )
    )
    expect(config['name']).to eq('test_name')
    end

    it 'configures elastic search hosts from properties succesfully' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 1234,
                'hosts' => ['127.0.0.1','127.0.0.2']
              }
            } 
          },
          consumes: []
        )
      )
      expect(config['output.elasticsearch']['hosts']).to eq([
          'https://127.0.0.1:1234',
          'https://127.0.0.2:1234'
        ]
      )
    end

    it 'configures elastic search hosts from link succesfully' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 1234
              }
            } 
          },
          consumes: [elasticsearch_link]
        )
      )
      expect(config['output.elasticsearch']['hosts']).to eq([
          'https://10.0.0.10:1234',
          'https://10.0.0.20:1234',
          'https://10.0.0.30:1234'
        ]
      )
    end
    it 'configures Kibana host from link succesfully' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 1234
              },
              'kibana' => {
                'protocol' => 'https',
                'port' => 443
              }
            }
          },
          consumes: [kibana_link]
        )
      )
      expect(config['setup.kibana']['host']).to eq('https://10.0.0.50:443')
    end
    it 'does not configure Kibana host' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 1234
              }
            }
          },
          consumes: []
        )
      )
      expect(config['setup.kibana']).to eq(nil)
    end
    it 'configures ILM policies options by default' do
      config = YAML.load(template.render({
        'metricbeat' => {
          'elasticsearch' => {
            'port' => 1234
          }
        }
      }))
  
      expect(config['setup.ilm.enabled']).to eq('auto')
      expect(config['setup.ilm.rollover_alias']).to eq('metricbeat-%{[agent.version]}')
      expect(config['setup.ilm.pattern']).to eq('%{now/d}-000001')
      expect(config['setup.ilm.policy_name']).to eq('metricbeat-%{[agent.version]}')
      expect(config['setup.ilm.check_exists']).to eq('false')
      expect(config['setup.ilm.overwrite']).to eq('true')
    end
  end

  describe 'config/modules.d/kafka.yml.disabled' do
    let(:template) { job.template('config/modules.d/kafka.yml.disabled') }
    
    it 'loads defaults for kafka module' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'modules' => {
                'kafka' => {
                   
                }
              }
            }
          },
          consumes: []
        )
      )
      # my.bosh.com is spec.address is default in this test library
      expect(config.first['module']).to eq('kafka')
      expect(config.first['hosts']).to eq(['my.bosh.com:9092'])
    end

    it 'loads from kafka config from link' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'modules' => {
                'kafka' => {
                   
                }
              }
            }
          },
          consumes: [kafka_link]
        )
      )
      expect(config.first['module']).to eq('kafka')
      expect(config.first['hosts']).to eq(["my.bosh.com:9092"])
    end
  end

  describe 'config/modules.d/zookeeper.yml.disabled' do
    let(:template) { job.template('config/modules.d/zookeeper.yml.disabled') }
    it 'loads defaults for zookeeper module' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'modules' => {
                'zookeeper' => {
                   
                }
              }
            }
          },
          consumes: []
        )
      )
      # my.bosh.com is spec.address is default in this test library
      expect(config.first['module']).to eq('zookeeper')
      expect(config.first['hosts']).to eq(['my.bosh.com:2181'])
    end

    it 'loads from zookeeper config from link' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'modules' => {
                'zookeeper' => {
                   
                }
              }
            }
          },
          consumes: [zookeeper_link]
        )
      )
      expect(config.first['module']).to eq('zookeeper')
      expect(config.first['hosts']).to eq(["my.bosh.com:2181"])
    end
  end
  
  describe 'config/modules.d/redis.yml.disabled' do
    let(:template) { job.template('config/modules.d/redis.yml.disabled') }
    it 'loads defaults for redis module' do
      config = YAML.load(template.render(
          {},
          consumes: []
        )
      )
      # my.bosh.com is spec.address is default in this test library
      expect(config.first['module']).to eq('redis')
      expect(config.first).not_to have_key('password')
    end

    it 'loads defaults for redis module' do
      config = YAML.load(template.render(
        {},
        consumes: [redis_link]
      ))
      # my.bosh.com is spec.address is default in this test library
      expect(config.first['module']).to eq('redis')
      expect(config.first.dig('password')).to eq('asdf1234')
      expect(config.first.dig('hosts')).to eq(['my.bosh.com:4321'])
    end
  end
  describe 'config/metricbeat_ilm_policy.json' do
    let(:template) { job.template('config/metricbeat_ilm_policy.json') }

    it 'renders the policy from a given policy hash' do
      policy = JSON.load(template.render({}))

      expect(policy['policy']['phases']['delete']['min_age']).to eq '7d'
    end
  end
end