{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Monomer.Widgets.Radio (
  RadioCfg,
  radio,
  radio_,
  radioV,
  radioV_,
  radioD_,
  radioWidth
) where

import Control.Applicative ((<|>))
import Control.Lens (ALens', (&), (^.), (.~))
import Control.Monad
import Data.Default
import Data.Maybe
import Data.Text (Text)

import Monomer.Widgets.Single

import qualified Monomer.Lens as L

data RadioCfg s e a = RadioCfg {
  _rdcWidth :: Maybe Double,
  _rdcOnFocus :: [e],
  _rdcOnFocusReq :: [WidgetRequest s],
  _rdcOnBlur :: [e],
  _rdcOnBlurReq :: [WidgetRequest s],
  _rdcOnChange :: [a -> e],
  _rdcOnChangeReq :: [WidgetRequest s]
}

instance Default (RadioCfg s e a) where
  def = RadioCfg {
    _rdcWidth = Nothing,
    _rdcOnFocus = [],
    _rdcOnFocusReq = [],
    _rdcOnBlur = [],
    _rdcOnBlurReq = [],
    _rdcOnChange = [],
    _rdcOnChangeReq = []
  }

instance Semigroup (RadioCfg s e a) where
  (<>) t1 t2 = RadioCfg {
    _rdcWidth = _rdcWidth t2 <|> _rdcWidth t1,
    _rdcOnFocus = _rdcOnFocus t1 <> _rdcOnFocus t2,
    _rdcOnFocusReq = _rdcOnFocusReq t1 <> _rdcOnFocusReq t2,
    _rdcOnBlur = _rdcOnBlur t1 <> _rdcOnBlur t2,
    _rdcOnBlurReq = _rdcOnBlurReq t1 <> _rdcOnBlurReq t2,
    _rdcOnChange = _rdcOnChange t1 <> _rdcOnChange t2,
    _rdcOnChangeReq = _rdcOnChangeReq t1 <> _rdcOnChangeReq t2
  }

instance Monoid (RadioCfg s e a) where
  mempty = def

instance CmbOnFocus (RadioCfg s e a) e where
  onFocus fn = def {
    _rdcOnFocus = [fn]
  }

instance CmbOnFocusReq (RadioCfg s e a) s where
  onFocusReq req = def {
    _rdcOnFocusReq = [req]
  }

instance CmbOnBlur (RadioCfg s e a) e where
  onBlur fn = def {
    _rdcOnBlur = [fn]
  }

instance CmbOnBlurReq (RadioCfg s e a) s where
  onBlurReq req = def {
    _rdcOnBlurReq = [req]
  }

instance CmbOnChange (RadioCfg s e a) a e where
  onChange fn = def {
    _rdcOnChange = [fn]
  }

instance CmbOnChangeReq (RadioCfg s e a) s where
  onChangeReq req = def {
    _rdcOnChangeReq = [req]
  }

radioWidth :: Double -> RadioCfg s e a
radioWidth w = def {
  _rdcWidth = Just w
}

radio :: (Eq a) => ALens' s a -> a -> WidgetNode s e
radio field option = radio_ field option def

radio_ :: (Eq a) => ALens' s a -> a -> [RadioCfg s e a] -> WidgetNode s e
radio_ field option configs = radioD_ (WidgetLens field) option configs

radioV :: (Eq a) => a -> (a -> e) -> a -> WidgetNode s e
radioV value handler option = radioV_ value handler option def

radioV_
  :: (Eq a) => a -> (a -> e) -> a -> [RadioCfg s e a] -> WidgetNode s e
radioV_ value handler option configs = newNode where
  widgetData = WidgetValue value
  newConfigs = onChange handler : configs
  newNode = radioD_ widgetData option newConfigs

radioD_
  :: (Eq a)
  => WidgetData s a
  -> a
  -> [RadioCfg s e a]
  -> WidgetNode s e
radioD_ widgetData option configs = radioNode where
  config = mconcat configs
  widget = makeRadio widgetData option config
  radioNode = defaultWidgetNode "radio" widget
    & L.widgetInstance . L.focusable .~ True

makeRadio :: (Eq a) => WidgetData s a -> a -> RadioCfg s e a -> Widget s e
makeRadio field option config = widget where
  baseWidget = createSingle def {
    singleGetBaseStyle = getBaseStyle,
    singleGetSizeReq = getSizeReq,
    singleRender = render
  }
  widget = baseWidget {
    widgetHandleEvent = localEventWrapper
  }

  getBaseStyle wenv node = Just style where
    style = collectTheme wenv L.radioStyle

  localEventWrapper wenv target evt node
    | not (node ^. L.widgetInstance . L.visible) = Nothing
    | otherwise = handleStyleChange_ wenv target evt style_ result cfg node
    where
      cfg = StyleChangeCfg isOnMove
      radioArea = getRadioArea wenv node config
      style_ = activeStyle_ (isHoveredEllipse_ radioArea) wenv node
      result = handleEvent wenv target evt node

  handleEvent wenv target evt node = case evt of
    Focus -> handleFocusChange _rdcOnFocus _rdcOnFocusReq config node
    Blur -> handleFocusChange _rdcOnBlur _rdcOnBlurReq config node
    Click p _
      | pointInEllipse p rdArea -> Just $ resultReqsEvts node clickReqs events
    KeyAction mod code KeyPressed
      | isSelectKey code -> Just $ resultReqsEvts node reqs events
    _ -> Nothing
    where
      rdArea = getRadioArea wenv node config
      path = node ^. L.widgetInstance . L.path
      isSelectKey code = isKeyReturn code || isKeySpace code
      events = fmap ($ option) (_rdcOnChange config)
      setValueReq = widgetDataSet field option
      setFocusReq = SetFocus path
      reqs = setValueReq ++ _rdcOnChangeReq config
      clickReqs = setFocusReq : reqs

  getSizeReq wenv node = req where
    theme = activeTheme wenv node
    width = fromMaybe (theme ^. L.radioWidth) (_rdcWidth config)
    req = (FixedSize width, FixedSize width)

  render renderer wenv node = do
    renderRadio renderer radioBW radioArea fgColor

    when (value == option) $
      renderMark renderer radioBW radioArea fgColor
    where
      model = _weModel wenv
      value = widgetDataGet model field
      radioArea = getRadioArea wenv node config
      radioBW = max 1 (_rW radioArea * 0.1)
      style_ = activeStyle_ (isHoveredEllipse_ radioArea) wenv node
      fgColor = styleFgColor style_

getRadioArea :: WidgetEnv s e -> WidgetNode s e -> RadioCfg s e a -> Rect
getRadioArea wenv node config = radioArea where
  theme = activeTheme wenv node
  style = activeStyle wenv node
  rarea = getContentArea style node
  radioW = fromMaybe (theme ^. L.radioWidth) (_rdcWidth config)
  radioL = _rX rarea + (_rW rarea - radioW) / 2
  radioT = _rY rarea + (_rH rarea - radioW) / 2
  radioArea = Rect radioL radioT radioW radioW

renderRadio :: Renderer -> Double -> Rect -> Color -> IO ()
renderRadio renderer radioBW rect color = action where
  action = drawEllipseBorder renderer rect (Just color) radioBW

renderMark :: Renderer -> Double -> Rect -> Color -> IO ()
renderMark renderer radioBW rect color = action where
  w = radioBW * 2
  newRect = fromMaybe def (subtractFromRect rect w w w w)
  action = drawEllipse renderer newRect (Just color)

isHoveredEllipse_ :: Rect -> WidgetEnv s e -> WidgetNode s e -> Bool
isHoveredEllipse_ area wenv node = validPos && isTopLevel wenv node where
  mousePos = wenv ^. L.inputStatus . L.mousePos
  validPos = pointInEllipse mousePos area
