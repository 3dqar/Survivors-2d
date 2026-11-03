-- ServerScriptService/Survivors/Support.server.lua
-- Donation-only Developer Products: no coins, weapons, powers, or other benefits.
-- This MUST remain the game's only MarketplaceService.ProcessReceipt callback.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local products = require(ReplicatedStorage:WaitForChild("SurvivorsShared"):WaitForChild("SupportProducts"))
local known = {}
for _, item in ipairs(products) do
    if type(item.id) == "number" and item.id > 0 then
        assert(not known[item.id], "Duplicate Support Developer Product ID")
        known[item.id] = item
    end
end

MarketplaceService.ProcessReceipt = function(receipt)
    local product = known[receipt.ProductId]
    if not product then
        warn("[Survivors Support] Unrecognized product receipt " .. tostring(receipt.ProductId) .. "; not acknowledged.")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    -- Donations have no virtual entitlement to grant; Roblox handles Robux settlement.
    -- Only acknowledge receipts of our configured support products.
    print(string.format("[Survivors Support] User %s supported the creator (%s Robux tier). Receipt %s",
        tostring(receipt.PlayerId), tostring(product.robux), tostring(receipt.PurchaseId)))
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
