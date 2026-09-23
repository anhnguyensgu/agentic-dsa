# A small known-correct solution used only by the optional live run smoke test.
class Solution:
    def twoSum(self, nums, target):
        seen = {}
        for index, number in enumerate(nums):
            if target - number in seen:
                return [seen[target - number], index]
            seen[number] = index
