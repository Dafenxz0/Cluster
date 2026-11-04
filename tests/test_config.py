import json
import tempfile
import unittest
from pathlib import Path
from api.config import load_nodes


class ConfigTests(unittest.TestCase):
    def test_example_configuration(self):
        nodes = load_nodes('examples/nodes.example.json')
        self.assertEqual(len(nodes), 3)
        self.assertEqual(nodes[0].base_url, 'http://192.168.50.10:8000')

    def test_duplicate_names_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'nodes.json'
            path.write_text(json.dumps({'nodes': [{'name': 'a', 'host': '127.0.0.1'}, {'name': 'a', 'host': '127.0.0.2'}]}))
            with self.assertRaises(ValueError):
                load_nodes(str(path))


if __name__ == '__main__':
    unittest.main()
