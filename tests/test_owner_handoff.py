"""Exercise the real handoff shell script with an explicitly fake Terraform CLI."""
from pathlib import Path
import json, os, subprocess, tempfile, unittest

ROOT = Path(__file__).resolve().parents[1]

class OutputHandoff(unittest.TestCase):
    def run_case(self, fail):
        with tempfile.TemporaryDirectory(prefix='aks-handoff-', dir=os.environ.get('TMPDIR')) as directory:
            root = Path(directory)
            tooling = root / 'example/observability'
            tooling.mkdir(parents=True)
            target = tooling/'owner.auto.tfvars.json'
            target.write_text('{"unchanged":true}')
            payload = {'environment': {'collector_client_id':'TEST-COLLECTOR',
                                      'grafana_client_id':'TEST-GRAFANA',
                                      'trace_endpoint':'https://generated.test/trace'}}
            (root/'output.json').write_text(json.dumps(payload))
            fake = root/'terraform'
            fake.write_text('#!/usr/bin/env python3\nimport os,sys,pathlib\n'
                            'if sys.argv[-1] == "observability_inputs":\n'
                            ' if os.environ["TEST_FAIL"] == "yes":\n'
                            '  print("partial"); sys.exit(7)\n'
                            ' print(pathlib.Path(os.environ["TEST_OUTPUT"]).read_text())\n'
                            'else: print("{}")\n')
            fake.chmod(0o700)
            env = {'PATH':str(root)+':'+os.environ['PATH'], 'HOME':str(root),
                   'TMPDIR':directory, 'EXAMPLE_ROOT':str(root/'example'),
                   'OWNER_ROOT':str(root/'not-a-real-state'),
                   'TEST_FAIL':'yes' if fail else 'no', 'TEST_OUTPUT':str(root/'output.json')}
            result = subprocess.run(['bash',str(ROOT/'example/steps/00-owner-output.sh')],
                                    env=env, capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 7 if fail else 0)
            self.assertEqual(json.loads(target.read_text()), {'unchanged':True} if fail else payload)
            self.assertFalse(list(tooling.glob('.owner-inputs.*')))
    def test_generated_output_reaches_helm_input_file(self):
        self.run_case(False)
    def test_failed_output_preserves_previous_complete_file(self):
        self.run_case(True)

if __name__ == '__main__':
    unittest.main()
