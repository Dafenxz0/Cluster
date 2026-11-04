import asyncio
import unittest
from api.balancer import LeastBusyPool


class PoolTests(unittest.IsolatedAsyncioTestCase):
    async def test_rotating_ties(self):
        pool = LeastBusyPool(["head", "worker-a", "worker-b"])
        names = []
        for _ in range(3):
            name = await pool.reserve()
            names.append(name)
            await pool.release(name)
        self.assertEqual(names, ["head", "worker-a", "worker-b"])

    async def test_least_busy(self):
        pool = LeastBusyPool(["head", "worker-a"])
        one = await pool.reserve()
        two = await pool.reserve()
        self.assertNotEqual(one, two)
        self.assertEqual((await pool.snapshot())[one], 1)
        await pool.release(one)
        await pool.release(two)
        self.assertEqual(await pool.snapshot(), {"head": 0, "worker-a": 0})

    async def test_exclusion(self):
        pool = LeastBusyPool(["a", "b"])
        self.assertEqual(await pool.reserve({"a"}), "b")
        await pool.release("b")
        with self.assertRaises(ValueError):
            await pool.reserve({"a", "b"})

    async def test_invalid(self):
        with self.assertRaises(ValueError):
            LeastBusyPool(["a", "a"])
        pool = LeastBusyPool(["a"])
        with self.assertRaises(ValueError):
            await pool.release("a")


if __name__ == "__main__":
    unittest.main()
