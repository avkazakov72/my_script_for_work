import unittest
from src.main import greet

class TestGreet(unittest.TestCase):
    def test_greet_default(self):
        self.assertEqual(greet(), "Hello, World!")
    
    def test_greet_name(self):
        self.assertEqual(greet("Alice"), "Hello, Alice!")

if __name__ == "__main__":
    unittest.main()
