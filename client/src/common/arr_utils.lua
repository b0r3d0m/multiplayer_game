function removeIf(arr, pred)
  for i=#arr,1,-1 do
    if pred(arr[i]) then
      table.remove(arr, i)
    end
  end
end

function arrContains(arr, val)
  for index, value in ipairs(arr) do
    if value == val then
      return true
    end
  end
  return false
end

