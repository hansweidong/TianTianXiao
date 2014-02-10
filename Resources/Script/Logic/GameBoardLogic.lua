require "Script/Config/CommonDefine"


--��ʼ�������и���index��Ϊ0

GameBoard = {}

for i=1, GBoardSizeX do
  GameBoard[i] = {}
  for j=1, GBoardSizeY do
    GameBoard[i][j] = 0
  end
end

--��ȡĳ�����ӵ���������
function getCellCenterPoint(cell)
  local point = {}
  point.x = (cell.x - 1) * GCellWidth + GLeftBottomOffsetX + GCellWidth / 2
  point.y = (cell.y - 1) * GCellWidth + GLeftBottomOffsetY + GCellWidth / 2
  return point
end

--���ĳ�������Ƿ����3��,����GameBoard����
function checkCell(cell)
  local x = cell.x
  local y = cell.y

  local index = GameBoard[x][y]
  local ret = false

  local cond = {}
  cond[1] = x > 1 and GameBoard[x-1][y] == index
  cond[2] = x > 2 and GameBoard[x-2][y] == index
  cond[3] = x < GBoardSizeX and GameBoard[x+1][y] == index
  cond[4] = x < GBoardSizeX-1 and GameBoard[x+2][y] == index
  cond[5] = y > 1 and GameBoard[x][y-1] == index
  cond[6] = y > 2 and GameBoard[x][y-2] == index
  cond[7] = y < GBoardSizeY and GameBoard[x][y+1] == index
  cond[8] = y < GBoardSizeY-1 and GameBoard[x][y+2] == index

  if (cond[1] and cond[2]) or (cond[1] and cond[3]) or (cond[3] and cond[4]) or
    (cond[5] and cond[6]) or (cond[5] and cond[7]) or (cond[7] and cond[8]) then
    ret = true
  end

  return ret
end

--������ת��Ϊ���̸��ӵ�
function touchPointToCell(x, y)
  local cellX = math.modf((x - GLeftBottomOffsetX) / GCellWidth)
  local cellY = math.modf((y - GLeftBottomOffsetY) / GCellWidth)
  local cell = {}
  cell.x = cellX + 1
  cell.y = cellY + 1

  if cell.x > GBoardSizeX or x < GLeftBottomOffsetX or cell.y > GBoardSizeY or y < GLeftBottomOffsetY then
    cell.x = 0
    cell.y = 0
  end

  return cell
end

--������������Ƿ�����
function isTwoCellNearby(cellA, cellB)
  local ret = false
  if (math.abs(cellA.x - cellB.x) == 1 and cellA.y == cellB.y) or
    (math.abs(cellA.y - cellB.y) == 1 and cellA.x == cellB.x) then
    print("xiang lin ")
    print(ret)
    ret = true
  end
  return ret
end


--�����ĳ������ͬɫ�����ĸ��Ӽ���
function getNearbyCellSet(cell)
  local x = cell.x
  local y = cell.y
  local index = GameBoard[x][y]

  local cellSet = {}
  cellSet[#cellSet + 1] = {x = x, y = y}

  local assArray = {}
  local function addCellToSet(cell)
    if assArray[10 * cell.x + cell.y] == nil then
      cellSet[#cellSet + 1] = cell
      assArray[10 * cell.x + cell.y] = true
    end
  end

  local cond = {}
  cond[1] = x > 1 and GameBoard[x-1][y] == index
  cond[2] = x > 2 and GameBoard[x-2][y] == index
  cond[3] = x < GBoardSizeX and GameBoard[x+1][y] == index
  cond[4] = x < GBoardSizeX-1 and GameBoard[x+2][y] == index
  cond[5] = y > 1 and GameBoard[x][y-1] == index
  cond[6] = y > 2 and GameBoard[x][y-2] == index
  cond[7] = y < GBoardSizeY and GameBoard[x][y+1] == index
  cond[8] = y < GBoardSizeY-1 and GameBoard[x][y+2] == index

  if cond[1] and cond[2] then
    addCellToSet({x = x-1, y = y})
    addCellToSet({x = x-2, y = y})
  end

  if cond[1] and cond[3] then
    addCellToSet({x = x-1, y = y})
    addCellToSet({x = x+1, y = y})
  end

  if cond[3] and cond[4] then
    addCellToSet({x = x+1, y = y})
    addCellToSet({x = x+2, y = y})
  end

  if cond[5] and cond[6] then
    addCellToSet({x = x, y = y-1})
    addCellToSet({x = x, y = y-2})
  end

  if cond[5] and cond[7] then
    addCellToSet({x = x, y = y-1})
    addCellToSet({x = x, y = y+1})
  end

  if cond[7] and cond[8] then
    addCellToSet({x = x, y = y+1})
    addCellToSet({x = x, y = y+2})
  end

  return cellSet
end
--���������������������������������
function getRefreshBoardData()

  --��¼ÿ����������Ŀո�
  local firstEmptyCell = {}

  --��¼ÿ������Ҫ���ӵ�����
  local addCellList = {}

  --��¼ÿ����Ҫ�ƶ�������
  local moveCellList = {}

  for i = 1, GBoardSizeX do
    for j = 1, GBoardSizeY do
      if GameBoard[i][j] == 0 then
        if firstEmptyCell[i] == nil then
          firstEmptyCell[i] = {x = i, y = j}
        end

        --�������index�������Ӧ�е�addList
        math.randomseed(math.random(os.time()))
        local addIconIndex = math.random(GGameIconCount)

        if addCellList[i] == nil then
          addCellList[i] = {}
        end
        addCellList[i][#(addCellList[i]) + 1] = addIconIndex
      else
        if moveCellList[i] == nil then
          moveCellList[i] = {}
        end
        --�ж��Ƿ��Ѿ��������սڵ�
        if firstEmptyCell[i] ~= nil then
          moveCellList[i][#(moveCellList[i]) + 1] = {x = i, y = j}
        end
      end
    end
  end

  return firstEmptyCell, addCellList, moveCellList
end

--������ɳ�ʼ����

function initGameBoard()
  for x=1, GBoardSizeX do
    for y=1, GBoardSizeY do
      repeat
        math.randomseed(math.random(os.time()))
        GameBoard[x][y] = math.random(GGameIconCount)
      until checkCell({x = x, y = y}) == false
    end
  end
end


--����������޿��ƶ���������
function checkBoardMovable()
  local ret = false

  --��⽻�������ڵ����ݺ������Ƿ������
  local function checkTwinCell(cellA, cellB)
    local ret = false

    GameBoard[cellA.x][cellA.y], GameBoard[cellB.x][cellB.y] = GameBoard[cellB.x][cellB.y], GameBoard[cellA.x][cellA.y]
    ret = checkCell(cellA) or checkCell(cellB)
    GameBoard[cellA.x][cellA.y], GameBoard[cellB.x][cellB.y] = GameBoard[cellB.x][cellB.y], GameBoard[cellA.x][cellA.y]

    return ret
  end

  local succList = {}

  --���¼��
  for i = 1, GBoardSizeX do
    for j = 1, GBoardSizeY - 1 do
      local cellA = {x = i, y = j}
      local cellB = {x = i, y = j + 1}
      if checkTwinCell(cellA, cellB) then
        succList[#succList + 1] = cellA
      end
    end
  end

  --���Ҽ��
  for i = 1, GBoardSizeX - 1 do
    for j = 1, GBoardSizeY do
      local cellA = {x = i, y = j}
      local cellB = {x = i + 1, y = j}
      if checkTwinCell(cellA, cellB) then
        succList[#succList + 1] = cellA
      end
    end
  end

  if #succList > 0 then
    cclog("check success!!!")
    ret = true
  end

  return ret, succList
end