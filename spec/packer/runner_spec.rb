require 'packer/runner'

describe Packer::Runner do
  describe 'run' do
    it 'returns its exit status and output' do
      temp_file = Tempfile.new('')
      config = {
        "builders" => [{
          "type" => "file",
          "content" => "contents",
          "target" => temp_file.path
      }]}
      packer_runner = Packer::Runner.new(config)
      exit_status, output = packer_runner.run('build')
      expect(output).to include(",ui,say,Build 'file' finished.")
      expect(File.read(temp_file.path)).to eq('contents')
      expect(exit_status).to eq(0)
    end

    context 'when arguments are provided' do
      it 'passes them to packer' do
        temp_file = Tempfile.new('')
        contents = 'some-contents'
        config = {
          "builders" => [{
            "type" => "file",
            "content" => "{{user `contents`}}",
            "target" => temp_file.path
          }]}
        packer_runner = Packer::Runner.new(config)
        exit_status, output = packer_runner.run('build', {contents: contents})
        expect(output).to include(",ui,say,Build 'file' finished.")
        expect(File.read(temp_file.path)).to eq(contents)
        expect(exit_status).to eq(0)
      end
    end

    context 'when provided an invalid command' do
      it 'returns a non-zero exit status' do
        packer_runner = Packer::Runner.new('')
        exit_status, _ = packer_runner.run('invalid-command', {})
        expect(exit_status).not_to eq(0)
      end
    end
  end
end
