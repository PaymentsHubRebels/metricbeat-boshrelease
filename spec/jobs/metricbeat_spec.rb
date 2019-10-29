require 'rspec'
require 'yaml'
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

  describe 'metricbeat.yml' do
    let(:template) { job.template('config/metricbeat.yml') }

    it 'configures the shipper name properly when specified in properties' do 
      config = YAML.load(template.render(
        {
          'metricbeat' => {
            'name' => 'test_name'
          } 
        },
        consumes: []
      )
    )
    expect(config['name']).to eq('test_name')
    end

    it 'configures the shipper name properly by default getting info from BOSH context' do 
      config = YAML.load(template.render(
        {},
        consumes: []
      )
    )
    expect(config['name']).to eq('my-deployment/me/0')
    end

    it 'configures elastic search hosts from properties succesfully' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 9201,
                'hosts' => ['127.0.0.1','127.0.0.2']
              }
            } 
          },
          consumes: []
        )
      )
      expect(config['output.elasticsearch']['hosts']).to eq([
          'https://127.0.0.1:9201',
          'https://127.0.0.2:9201'
        ]
      )
    end

    it 'configures elastic search hosts from link succesfully' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 9201,
              }
            } 
          },
          consumes: [elasticsearch_link]
        )
      )
      expect(config['output.elasticsearch']['hosts']).to eq([
          'https://10.0.0.10:9201',
          'https://10.0.0.20:9201',
          'https://10.0.0.30:9201'
        ]
      )
    end
    it 'configures Kibana host from link succesfully' do
      config = YAML.load(template.render(
          {
            'metricbeat' => {
              'elasticsearch' => {
                'protocol' => 'https',
                'port' => 9201,
              },
              'kibana' => {
                'protocol' => 'https',
                'port' => 443,
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
                'port' => 9201,
              }
            }
          },
          consumes: []
        )
      )
      expect(config['setup.kibana']).to eq(nil)
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
      expect(config.first['hosts']).to eq(['10.0.0.1:9092','10.0.0.2:9092', '10.0.0.3:9092'])
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
      expect(config.first['hosts']).to eq(['10.0.1.1:2181','10.0.1.2:2181', '10.0.1.3:2181'])
    end
  end
end