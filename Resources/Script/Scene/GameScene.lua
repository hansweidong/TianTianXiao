require "Script/Logic/GameBoardLogic"
require "Script/Sprite/GameIcon"
local scene = nil
local NODE_TAG_START = 10000

local NORMAL_TAG = 10
local MATCH_TAG = 30
local SELECT_TAG = 40
local visibleSize = CCDirector:sharedDirector():getVisibleSize()
local curSelectTag = nil

local isTouching = false
local isMoving = false
local isRefreshing = false
local REMOVED_TAG = 20000
local FALLING_TAG = 30000
local BLINK_TAG   = 40000
local touchStartPoint = {}
local touchEndPoint = {}

local touchStartCell = {}
local touchEndCell = {}


local succCellSet = {}
local switchCellSet = {}
local fallCellSet = {}
--ִ�и��ֺ����ĸ���node
local RefreshBoardNode = nil
local FallEndCheckNode = nil
--���ڴ洢ִ�н������
local switchCellPair = {}
--��˸�ڵ�
local blinkCell = nil

--����index����ĳ���ͽ�㣬������������Ϣ
local function createNodeByIndex(index)
  local iconNormalSprite = getGameIconSprite(GIconNormalType, index)
  local iconMatchSprite = getGameIconSprite(GIconMatchType, index)
  local iconSelectSprite = getGameIconSprite(GIconSelectType, index)

  iconNormalSprite:setTag(NORMAL_TAG)
  iconMatchSprite:setTag(MATCH_TAG)
  iconSelectSprite:setTag(SELECT_TAG)

  iconMatchSprite:setVisible(false)
  iconSelectSprite:setVisible(false)

  local iconNode = CCNode:create()
  iconNode:addChild(iconNormalSprite)
  iconNode:addChild(iconMatchSprite)
  iconNode:addChild(iconSelectSprite)

  return iconNode
end

--����ĳ��λ���ϵĽ��ͼ��
local function createNodeByCell(cell)
  local index = GameBoard[cell.x][cell.y]
  local iconNode = createNodeByIndex(index)

  iconNode:setTag(NODE_TAG_START + 10 * cell.x + cell.y)

  local cellPoint = getCellCenterPoint(cell)
  iconNode:setPosition(CCPoint(cellPoint.x, cellPoint.y))

  return iconNode
end

--��ʼ������ͼ��
local function initGameBoardIcon()
  for x=1, GBoardSizeX do
    for y = 1, GBoardSizeY do
      local iconNode = createNodeByCell({x = x, y = y})
      scene:addChild(iconNode)
    end
  end
end

--����֮ǰѡ�����ӵ�ѡ��״̬
local function resetSelectGameIcon()
  if curSelectTag ~= nil then
    local cellNode = scene:getChildByTag(NODE_TAG_START + curSelectTag)
    if cellNode ~= nil then
      local normalSprite = cellNode:getChildByTag(NORMAL_TAG)
      local selectSprite = cellNode:getChildByTag(SELECT_TAG)
      if normalSprite ~= nil then
        normalSprite:setVisible(true)
      end

      if selectSprite ~= nil then
        selectSprite:setVisible(false)
      end
    end
    curSelectTag = nil
  end
end

--������Ӹ���ͼ��Ч��
local function onClickGameIcon(cell)

  if cell.x == 0 or cell.y == 0 then
    return
  end

  resetSelectGameIcon()

  curSelectTag = 10 * cell.x + cell.y
  print("curSelectTag"..curSelectTag)
  scene:getChildByTag(NODE_TAG_START + curSelectTag):getChildByTag(NORMAL_TAG):setVisible(false)
  scene:getChildByTag(NODE_TAG_START + curSelectTag):getChildByTag(SELECT_TAG):setVisible(true)
  AudioEngine.playEffect("Sound/A_select.wav")
end


--�����������ӣ���ִ�лص�����(һ��Ϊ����Ƿ�����)
local function switchCell(cellA, cellB, cfCallBack)
  cclog("switchCell...")
  cclog("cellA.."..cellA.x.." "..cellA.y)
  cclog("cellB.."..cellB.x.." "..cellB.y)
  isTouching = false

  resetSelectGameIcon()

  local tagA = 10 * cellA.x + cellA.y
  local tagB = 10 * cellB.x + cellB.y

  local cellPointA = getCellCenterPoint(cellA)
  local cellPointB = getCellCenterPoint(cellB)

  local nodeA = scene:getChildByTag(NODE_TAG_START + tagA)
  local nodeB = scene:getChildByTag(NODE_TAG_START + tagB)

  if nodeA == nil or nodeB == nil then
    cclog("can't find node!!")
    return
  end

  local moveToA = CCMoveTo:create(0.1, CCPoint(cellPointA.x, cellPointA.y))

  --�����Ļص���������A cell��
  local function moveAWithCallBack()

    local arrayOfActions = CCArray:create()

    local moveToB = CCMoveTo:create(0.1, CCPoint(cellPointB.x, cellPointB.y))
    arrayOfActions:addObject(moveToB)

    if cfCallBack ~= nil then
      --cclog("move with call back..")
      local callBack = CCCallFunc:create(cfCallBack)
      arrayOfActions:addObject(callBack)
    end

    local sequence = CCSequence:create(arrayOfActions)
    nodeA:runAction(sequence)
  end

  moveAWithCallBack()
  nodeB:runAction(moveToA)

  --swap tag
  nodeA:setTag(NODE_TAG_START + tagB)
  nodeB:setTag(NODE_TAG_START + tagA)

  --swap index
  GameBoard[cellA.x][cellA.y], GameBoard[cellB.x][cellB.y] = GameBoard[cellB.x][cellB.y], GameBoard[cellA.x][cellA.y]
end

--�Ƴ����ӻص�����
local function cfRemoveSelf(matchSprite)
  --cclog("cf remove self")
  if matchSprite == nil then
    cclog("remove failed")
  else
    matchSprite:getParent():removeFromParentAndCleanup(true)
  end
end

--��Ϊƥ��ͼ�겢�����ص�
local function cfMatchAndFade(node)
  if node ~= nil then
    local normalSprite = node:getChildByTag(NORMAL_TAG)
    local matchSprite = node:getChildByTag(MATCH_TAG)
    local selectSprite = node:getChildByTag(SELECT_TAG)
    if normalSprite ~= nil then
      normalSprite:setVisible(false)
    end

    if selectSprite ~= nil then
      selectSprite:setVisible(false)
    end

    if matchSprite ~= nil then
      matchSprite:setVisible(true)

      local arrayOfActions = CCArray:create()

      local fade = CCFadeOut:create(0.2)
      local removeFunc = CCCallFuncN:create(cfRemoveSelf)

      arrayOfActions:addObject(fade)
      arrayOfActions:addObject(removeFunc)

      local sequence = CCSequence:create(arrayOfActions)

      matchSprite:runAction(sequence)
    end
  end
end

--��ĳ�����ϵĸ��ӽ������Ƴ�
local function removeCellSet(cellSet)
  for i = 1, #cellSet do
    --cclog("remove.."..cellSet[i].x.."  "..cellSet[i].y)
    local tag = 10 * cellSet[i].x + cellSet[i].y
    local node = scene:getChildByTag(NODE_TAG_START + tag)

    --��ʱֱ���������
    node:setTag(REMOVED_TAG + tag)
    GameBoard[cellSet[i].x][cellSet[i].y] = 0

    node:runAction(CCCallFuncN:create(cfMatchAndFade))
  end
end

--ƥ��������ˢ����Ϸ���
local function cfRefreshBoard()
  --cclog("cfRefreshBoard..")
  local firstEmptyCell = nil
  local addCellList = nil
  local moveCellList = nil

  firstEmptyCell, addCellList, moveCellList = getRefreshBoardData()

  local actionNodeList = {}
  --����ÿһ��
  for i = 1, GBoardSizeX do
    if firstEmptyCell[i] ~= nil then
      --cclog("firstEmptyCell.."..i..".."..firstEmptyCell[i].x..firstEmptyCell[i].y)
      local nextDesCell = {x = firstEmptyCell[i].x, y = firstEmptyCell[i].y}
      for j = 1, #(moveCellList[i]) do

        local cell = {x = moveCellList[i][j].x, y = moveCellList[i][j].y}
        --cclog("moveCellList"..i..".."..cell.x..cell.y)
        local tag = 10 * cell.x + cell.y
        local node = scene:getChildByTag(NODE_TAG_START + tag)

        local desTag = 100 * GameBoard[cell.x][cell.y] + 10 * nextDesCell.x + nextDesCell.y
        node:setTag(FALLING_TAG + desTag)

        actionNodeList[#actionNodeList + 1] = {}
        actionNodeList[#actionNodeList][1] = node
        actionNodeList[#actionNodeList][2] = nextDesCell
        nextDesCell = {x = nextDesCell.x, y = nextDesCell.y + 1}
        --local desCell =
      end

      for j = 1, #(addCellList[i]) do
        --cclog("addCellList"..i..".."..addCellList[i][j])

        local node = createNodeByIndex(addCellList[i][j])
        local bornPoint = getCellCenterPoint({x = i, y = 10})

        node:setPosition(CCPoint(bornPoint.x, bornPoint.y))

        --�¼ӵĽ��tag�а����Լ���index��Ϣ
        local desTag = 100 * addCellList[i][j] + 10 * nextDesCell.x + nextDesCell.y
        node:setTag(FALLING_TAG + desTag)
        scene:addChild(node)

        actionNodeList[#actionNodeList + 1] = {}
        actionNodeList[#actionNodeList][1] = node
        actionNodeList[#actionNodeList][2] = nextDesCell
        nextDesCell = {x = nextDesCell.x, y = nextDesCell.y + 1}
      end
    end
  end

  --�ƶ���Ϻ�Ļص�����
  local function cfOnFallDownEnd(node)
    --cclog("fall down end...")
    local tag = node:getTag() - FALLING_TAG
    --cclog("tag.."..tag)
    local index = math.modf(tag / 100)

    --��ȡ��ȥ��index��Ϣ
    tag = tag - index * 100
    local x = math.modf(tag / 10)
    local y = tag % 10

    GameBoard[x][y] = index
    --cclog("nowTag.."..tag)
    node:setTag(NODE_TAG_START + tag)
  end

  --ִ�����䵽���̲���
  for i = 1, #actionNodeList do
    local node = actionNodeList[i][1]
    local desCell = actionNodeList[i][2]
    local desPos = getCellCenterPoint(desCell)
    local desPoint = CCPoint(desPos.x, desPos.y)

    local arrayOfActions = CCArray:create()

    local move = CCMoveTo:create(0.1, desPoint)
    local fallDownEndFunc = CCCallFuncN:create(cfOnFallDownEnd)

    arrayOfActions:addObject(move)
    arrayOfActions:addObject(fallDownEndFunc)

    local sequence = CCSequence:create(arrayOfActions)

    node:runAction(sequence)

    --����������ɼ�⼯��
    fallCellSet[#fallCellSet + 1] = desCell
  end

  actionNodeList = {}

  --��������Ƿ����µ�����
  --FallEndCheckNode
  local arrayOfActions = CCArray:create()

  local delay = CCDelayTime:create(0.2)
  local fallCheckFunc = CCCallFunc:create(cfCheckFallCell)

  arrayOfActions:addObject(delay)
  arrayOfActions:addObject(fallCheckFunc)

  local sequence = CCSequence:create(arrayOfActions)

  FallEndCheckNode:runAction(sequence)
end

local function onCheckSuccess(succCellSet)
  if #succCellSet == 0 then
    return
  end

  --ƥ��ɹ�
  cclog("switch success!!!")
  AudioEngine.playEffect("Sound/A_combo1.wav")

  --to do: ִ���������������
  --����ڽ����Ӽ���
  local matchCellSet = {}

  --���ڼ���Ƿ��Ѽ���
  local assSet = {}
  for i = 1, #succCellSet do
    local succCell = succCellSet[i]
    local nearbySet = getNearbyCellSet(succCell)
    for i = 1, #nearbySet do
      local cell = nearbySet[i]
      if assSet[10 * cell.x + cell.y] == nil then
        assSet[10 * cell.x + cell.y] = true
        matchCellSet[#matchCellSet + 1] = cell
      end
    end
  end
  removeCellSet(matchCellSet)

  --�ӳ�һ��ʱ���ˢ������
  local arrayOfActions = CCArray:create()

  local delay = CCDelayTime:create(0.2)
  local refreshBoardFunc = CCCallFunc:create(cfRefreshBoard)

  arrayOfActions:addObject(delay)
  arrayOfActions:addObject(refreshBoardFunc)

  local sequence = CCSequence:create(arrayOfActions)

  RefreshBoardNode:runAction(sequence)

end

--��������������䵽���̲��ı���������
local function addBlinkIconToBoard()

  --����������ʾ���������
  local blinkSprite = createBlinkIconSprite()
  local blinkStartPoint = getCellCenterPoint({x = 6, y = 10})
  blinkSprite:setPosition(blinkStartPoint.x, blinkStartPoint.y)
  blinkSprite:setTag(BLINK_TAG + GBlinkIconIndex)
  scene:addChild(blinkSprite)

  --����䵽����ĳ���㲢�ı�õ�����
  math.randomseed(math.random(os.time()))
  local x = math.random(GBoardSizeX)
  local y = math.random(GBoardSizeY)

  --��ǰ�޸��������ݷ�ֹ�����н���
  GameBoard[x][y] = GBlinkIconIndex
  blinkCell = {x = x, y = y}

  local fallEndPoint = getCellCenterPoint({x = x, y = y})


  local function cfblinkFallEnd()
    cclog("blink fall end..")
    local tag = 10 * blinkCell.x + blinkCell.y
    local node = scene:getChildByTag(NODE_TAG_START + tag)
    node:removeFromParentAndCleanup(true)
    scene:getChildByTag(BLINK_TAG + GBlinkIconIndex):setTag(NODE_TAG_START + tag)
  end

  local arrayOfActions = CCArray:create()

  local move = CCMoveTo:create(0.2, CCPoint(fallEndPoint.x , fallEndPoint.y))
  local blinkFallEnd = CCCallFunc:create(cfblinkFallEnd)

  arrayOfActions:addObject(move)
  arrayOfActions:addObject(blinkFallEnd)

  local sequence = CCSequence:create(arrayOfActions)

  blinkSprite:runAction(sequence)
end



--������µ������Ƿ�����
function cfCheckFallCell()
  cclog("cfCheckFallCell...")
  local boardMovable , succList= checkBoardMovable()
  if #succList <= 3 then
  --addBlinkIconToBoard()
  end
  --[[
  if boardMovable then
  cclog("checkBoardMovable true")
  cclog("succList size : "..#succList)
  else
  cclog("checkBoardMovable false ")
  addBlinkIconToBoard()
  end
  ]]

  --����Ϊ�ֲ�����
  local checkSet = {}
  for i = 1, #fallCellSet do
    checkSet[#checkSet + 1] = fallCellSet[i]
  end

  --����ȫ��table
  switchCellSet = {}

  --ƥ��ɹ��ĸ��ӵ�
  succCellSet = {}
  for i = 1, #checkSet do
    if checkCell(checkSet[i]) then
      succCellSet[#succCellSet + 1] = checkSet[i]
    end
  end

  if #succCellSet ~= 0 then
    onCheckSuccess(succCellSet)
  end
end

--��⻥�ཻ�������������Ƿ�����
function cfCheckSwitchCell()
  --cclog("cfCheckSwitchCell...")

  --����Ϊ�ֲ�����
  local checkSet = {}
  for i = 1, #switchCellSet do
    checkSet[#checkSet + 1] = switchCellSet[i]
  end

  --����ȫ��table
  switchCellSet = {}

  if #checkSet < 2 then
    return
  end

  --ƥ��ɹ��ĸ��ӵ�
  succCellSet = {}
  for i = 1, #checkSet do
    if checkCell(checkSet[i]) then
      succCellSet[#succCellSet + 1] = checkSet[i]
    end
  end

  if #succCellSet == 0 then
    --ƥ��ʧ��
    cclog("switch failed...")

    --��ԭ�ƶ�����ս�����
    switchCell(switchCellPair[1], switchCellPair[2], nil)
    switchCellPair = {}

    AudioEngine.playEffect("Sound/A_falsemove.wav")
  else
    onCheckSuccess(succCellSet)
  end
end

--������
local function createBackLayer()
  local backLayer = CCLayer:create()

  local backSprite = CCSprite:create("imgs/game_bg.png")
  backSprite:setPosition(backSprite:getContentSize().width / 2, backSprite:getContentSize().height / 2)

  backLayer:addChild(backSprite)


  return backLayer
end

--������
local function createTouchLayer()

  local touchColor = ccc4(255, 255, 255 ,0)
  local touchLayer = CCLayerColor:create(touchColor)

  touchLayer:changeWidthAndHeight(visibleSize.width, visibleSize.height)

  local function onTouchBegan(x, y)
    --cclog("touchLayerBegan: %.2f, %.2f", x, y)
    isTouching = true
    touchStartPoint = {x = x, y = y}
    touchStartCell = touchPointToCell(x, y)
    -- print("touchStartCell X "..touchStartCell.x .."touchStartCell y " ..touchStartCell.y)
    if curSelectTag ~= nil then
      local curSelectCell = {x = math.modf(curSelectTag / 10), y = curSelectTag % 10}
      if isTwoCellNearby(curSelectCell, touchStartCell) then
       
        switchCellSet = {}
        switchCellSet[#switchCellSet + 1] = curSelectCell
        switchCellSet[#switchCellSet + 1] = touchStartCell
        switchCellPair[1] = curSelectCell
        switchCellPair[2] = touchStartCell
        switchCell(curSelectCell, touchStartCell, cfCheckSwitchCell)

        return true
      end
    end

    onClickGameIcon(touchStartCell)

    return true
  end

  local function onTouchMoved(x, y)
    --cclog("touchLayerMoved: %.2f, %.2f", x, y)
    local touchCurCell = touchPointToCell(x, y)
    if  isTouching then
      if isTwoCellNearby(touchCurCell, touchStartCell) then
        switchCellSet = {}
        switchCellSet[#switchCellSet + 1] = touchCurCell
        switchCellSet[#switchCellSet + 1] = touchStartCell

        switchCellPair[1] = touchCurCell
        switchCellPair[2] = touchStartCell
        switchCell(touchCurCell, touchStartCell, cfCheckSwitchCell)
      end
    end
  end

  local function onTouchEnded(x, y)
    --cclog("touchLayerEnded: %.2f, %.2f", x, y)
    touchEndPoint = {x = x, y = y}
    touchEndCell = touchPointToCell(x, y)
    isTouching = false
  end


  local function onTouch(eventType, x, y)
    if eventType == "began" then
      return onTouchBegan(x, y)
    elseif eventType == "moved" then
      return onTouchMoved(x, y)
    elseif eventType == "ended" then
      return onTouchEnded(x, y)
    end
  end

  touchLayer:registerScriptTouchHandler(onTouch)
  touchLayer:setTouchEnabled(true)

  return touchLayer
end
-- create game scene
function CreateGameScene()
  scene = CCScene:create()
  scene:addChild(createBackLayer())
  print("game")
  AudioEngine.stopMusic(true)
  local bgMusicPath = CCFileUtils:sharedFileUtils():fullPathForFilename("Sound/bgm_game.wav")
  AudioEngine.playMusic(bgMusicPath, true)

  loadGameIcon()
  initGameBoard()
  initGameBoardIcon()
  --���������ӳ�ִ��ˢ�����̺����Ľڵ�
  RefreshBoardNode = CCNode:create()
  scene:addChild(RefreshBoardNode)
  scene:addChild(createTouchLayer(),1000)
  FallEndCheckNode = CCNode:create()
  scene:addChild(FallEndCheckNode)

  return scene
end