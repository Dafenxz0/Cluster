"""Small, framework-independent concurrent request scheduler.

This implementation picks the least busy node, breaking ties in a rotating
order, and does not invent performance metrics about the deployed cluster.
"""
import asyncio


class LeastBusyPool:
    def __init__(self, names: list[str]):
        if not names or len(set(names)) != len(names):
            raise ValueError("Pool requires unique nonempty node names")
        self._names = list(names)
        self._counts = {name: 0 for name in names}
        self._cursor = 0
        self._lock = asyncio.Lock()

    async def reserve(self, exclude: set[str] | None = None) -> str:
        exclude = exclude or set()
        async with self._lock:
            candidates = [n for n in self._names if n not in exclude]
            if not candidates:
                raise ValueError("No candidate nodes left")
            ranked = sorted(candidates, key=lambda n: (self._counts[n], (self._names.index(n) - self._cursor) % len(self._names)))
            selected = ranked[0]
            self._counts[selected] += 1
            self._cursor = (self._names.index(selected) + 1) % len(self._names)
            return selected

    async def release(self, name: str) -> None:
        async with self._lock:
            if name not in self._counts or self._counts[name] < 1:
                raise ValueError(f"No active reservation for {name}")
            self._counts[name] -= 1

    async def snapshot(self) -> dict[str, int]:
        async with self._lock:
            return dict(self._counts)
