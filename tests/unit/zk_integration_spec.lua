-- Unit tests for zk integration directory scanner
-- Note: These tests focus on the directory scanning logic only,
-- not the picker UI which requires user interaction

describe("ZK Integration - Directory Scanner", function()
    local temp_dir
    local zk_integration

    before_each(function()
        -- Create temporary test directory with nested structure
        temp_dir = vim.fn.tempname()
        vim.fn.mkdir(temp_dir, "p")
        vim.fn.mkdir(temp_dir .. "/journal", "p")
        vim.fn.mkdir(temp_dir .. "/journal/daily", "p")
        vim.fn.mkdir(temp_dir .. "/work", "p")
        vim.fn.mkdir(temp_dir .. "/work/projects", "p")
        vim.fn.mkdir(temp_dir .. "/archive", "p")
        vim.fn.mkdir(temp_dir .. "/.hidden", "p") -- Should be skipped

        -- Load zk integration module directly
        zk_integration = require('notes.integrations.zk')
    end)

    after_each(function()
        -- Cleanup temp directory
        if temp_dir and vim.fn.isdirectory(temp_dir) == 1 then
            vim.fn.delete(temp_dir, "rf")
        end
    end)

    describe("_get_notebook_directories", function()
        it("should find all directories recursively", function()
            local directories = zk_integration._get_notebook_directories(temp_dir)

            assert.is_not_nil(directories)
            assert.is_true(#directories > 0)

            -- Should include root
            local has_root = false
            for _, dir in ipairs(directories) do
                if dir == "." then
                    has_root = true
                    break
                end
            end
            assert.is_true(has_root, "Should include root directory")
        end)

        it("should include nested directories", function()
            local directories = zk_integration._get_notebook_directories(temp_dir)

            -- Convert to set for easier checking
            local dir_set = {}
            for _, dir in ipairs(directories) do
                dir_set[dir] = true
            end

            assert.is_true(dir_set["journal"], "Should include journal")
            assert.is_true(dir_set["work"], "Should include work")
            assert.is_true(dir_set["journal/daily"], "Should include nested journal/daily")
            assert.is_true(dir_set["work/projects"], "Should include nested work/projects")
            assert.is_true(dir_set["archive"], "Should include archive")
        end)

        it("should skip hidden directories", function()
            local directories = zk_integration._get_notebook_directories(temp_dir)

            -- Should not include .hidden directory (but root "." is OK)
            for _, dir in ipairs(directories) do
                if dir ~= "." then
                    assert.is_nil(dir:match("^%."), "Should not include hidden directories: " .. dir)
                    assert.is_nil(dir:match("/%."), "Should not include hidden subdirectories: " .. dir)
                end
            end
        end)

        it("should respect max_depth parameter", function()
            local directories = zk_integration._get_notebook_directories(temp_dir, 1)

            -- With depth 1, should include top-level but not nested
            local dir_set = {}
            for _, dir in ipairs(directories) do
                dir_set[dir] = true
            end

            assert.is_true(dir_set["journal"], "Should include top-level journal")
            assert.is_true(dir_set["work"], "Should include top-level work")
            assert.is_nil(dir_set["journal/daily"], "Should not include nested with depth=1")
            assert.is_nil(dir_set["work/projects"], "Should not include nested with depth=1")
        end)

        it("should sort directories alphabetically", function()
            local directories = zk_integration._get_notebook_directories(temp_dir)

            -- Root should always be first
            assert.are.equal(".", directories[1], "Root should be first")

            -- Check that remaining directories are sorted
            for i = 2, #directories - 1 do
                assert.is_true(directories[i] < directories[i + 1],
                    string.format("Directories should be sorted: %s should come before %s",
                        directories[i], directories[i + 1]))
            end
        end)

        it("should handle empty notebook directory", function()
            local empty_dir = vim.fn.tempname()
            vim.fn.mkdir(empty_dir, "p")

            local directories = zk_integration._get_notebook_directories(empty_dir)

            -- Should still return root
            assert.are.equal(1, #directories)
            assert.are.equal(".", directories[1])

            vim.fn.delete(empty_dir, "rf")
        end)

        it("should handle non-existent directory", function()
            local non_existent = temp_dir .. "/does_not_exist"

            local directories = zk_integration._get_notebook_directories(non_existent)

            -- Should return just root even if directory doesn't exist
            assert.are.equal(1, #directories)
            assert.are.equal(".", directories[1])
        end)

        it("should handle deeply nested directory structures", function()
            -- Create a deeper structure
            local deep_path = temp_dir .. "/level1/level2/level3"
            vim.fn.mkdir(deep_path, "p")

            local directories = zk_integration._get_notebook_directories(temp_dir, 5)

            local has_deep = false
            for _, dir in ipairs(directories) do
                if dir:match("level1/level2/level3") then
                    has_deep = true
                    break
                end
            end

            assert.is_true(has_deep, "Should find deeply nested directories")
        end)

        it("should handle directory names with special characters", function()
            -- Create directory with spaces and hyphens
            local special_dir = temp_dir .. "/my-notes 2024"
            vim.fn.mkdir(special_dir, "p")

            local directories = zk_integration._get_notebook_directories(temp_dir)

            local has_special = false
            for _, dir in ipairs(directories) do
                if dir == "my-notes 2024" then
                    has_special = true
                    break
                end
            end

            assert.is_true(has_special, "Should handle directory names with special characters")
        end)

        it("should exclude only dot-prefixed directories", function()
            -- Create various directories
            vim.fn.mkdir(temp_dir .. "/normal", "p")
            vim.fn.mkdir(temp_dir .. "/.hidden", "p")
            vim.fn.mkdir(temp_dir .. "/also.normal", "p") -- Has dot but not at start

            local directories = zk_integration._get_notebook_directories(temp_dir)

            local dir_set = {}
            for _, dir in ipairs(directories) do
                dir_set[dir] = true
            end

            assert.is_true(dir_set["normal"], "Should include normal directory")
            assert.is_true(dir_set["also.normal"], "Should include directory with dot in middle")
            assert.is_nil(dir_set[".hidden"], "Should exclude dot-prefixed directory")
        end)

        it("should return relative paths", function()
            local directories = zk_integration._get_notebook_directories(temp_dir)

            -- All paths should be relative (not absolute)
            for _, dir in ipairs(directories) do
                if dir ~= "." then
                    assert.is_nil(dir:match("^/"), "Paths should be relative, not absolute: " .. dir)
                    assert.is_nil(dir:match("^" .. vim.pesc(temp_dir)),
                        "Paths should not include notebook prefix: " .. dir)
                end
            end
        end)

        it("should handle max_depth of 0", function()
            local directories = zk_integration._get_notebook_directories(temp_dir, 0)

            -- With depth 0, should only return root
            assert.are.equal(1, #directories)
            assert.are.equal(".", directories[1])
        end)
    end)

    describe("directory picker data structure", function()
        it("should provide data suitable for picker display", function()
            local directories = zk_integration._get_notebook_directories(temp_dir)

            -- Verify structure is suitable for creating picker items
            assert.is_true(#directories > 0, "Should return directories")
            assert.are.equal(".", directories[1], "Root should be first")

            -- All items should be strings
            for _, dir in ipairs(directories) do
                assert.are.equal("string", type(dir), "All directories should be strings")
            end
        end)
    end)
end)
