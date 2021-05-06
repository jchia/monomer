{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Monomer.Widgets.Singles.Radio (
  radio,
  radio_,
  radioV,
  radioV_,
  radioD_
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
  _rdcOnFocus :: [Path -> e],
  _rdcOnFocusReq :: [WidgetRequest s e],
  _rdcOnBlur :: [Path -> e],
  _rdcOnBlurReq :: [WidgetRequest s e],
  _rdcOnChange :: [a -> e],
  _rdcOnChangeReq :: [WidgetRequest s e]
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

instance CmbWidth (RadioCfg s e a) where
  width w = def {
    _rdcWidth = Just w
  }

instance CmbOnFocus (RadioCfg s e a) e Path where
  onFocus fn = def {
    _rdcOnFocus = [fn]
  }

instance CmbOnFocusReq (RadioCfg s e a) s e where
  onFocusReq req = def {
    _rdcOnFocusReq = [req]
  }

instance CmbOnBlur (RadioCfg s e a) e Path where
  onBlur fn = def {
    _rdcOnBlur = [fn]
  }

instance CmbOnBlurReq (RadioCfg s e a) s e where
  onBlurReq req = def {
    _rdcOnBlurReq = [req]
  }

instance CmbOnChange (RadioCfg s e a) a e where
  onChange fn = def {
    _rdcOnChange = [fn]
  }

instance CmbOnChangeReq (RadioCfg s e a) s e where
  onChangeReq req = def {
    _rdcOnChangeReq = [req]
  }

radio :: (Eq a, WidgetEvent e) => ALens' s a -> a -> WidgetNode s e
radio field option = radio_ field option def

radio_ :: (Eq a, WidgetEvent e) => ALens' s a -> a -> [RadioCfg s e a] -> WidgetNode s e
radio_ field option configs = radioD_ (WidgetLens field) option configs

radioV :: (Eq a, WidgetEvent e) => a -> (a -> e) -> a -> WidgetNode s e
radioV value handler option = radioV_ value handler option def

radioV_ :: (Eq a, WidgetEvent e) => a -> (a -> e) -> a -> [RadioCfg s e a] -> WidgetNode s e
radioV_ value handler option configs = newNode where
  widgetData = WidgetValue value
  newConfigs = onChange handler : configs
  newNode = radioD_ widgetData option newConfigs

radioD_
  :: (Eq a, WidgetEvent e)
  => WidgetData s a
  -> a
  -> [RadioCfg s e a]
  -> WidgetNode s e
radioD_ widgetData option configs = radioNode where
  config = mconcat configs
  widget = makeRadio widgetData option config
  radioNode = defaultWidgetNode "radio" widget
    & L.info . L.focusable .~ True

makeRadio :: (Eq a, WidgetEvent e) => WidgetData s a -> a -> RadioCfg s e a -> Widget s e
makeRadio field option config = widget where
  widget = createSingle () def {
    singleGetBaseStyle = getBaseStyle,
    singleGetActiveStyle = getActiveStyle,
    singleHandleEvent = handleEvent,
    singleGetSizeReq = getSizeReq,
    singleRender = render
  }

  getBaseStyle wenv node = Just style where
    style = collectTheme wenv L.radioStyle

  getActiveStyle wenv node = style where
    radioArea = getRadioArea wenv node config
    style = activeStyle_ (activeStyleConfig radioArea) wenv node

  handleEvent wenv node target evt = case evt of
    Focus prev -> handleFocusChange _rdcOnFocus _rdcOnFocusReq config prev node
    Blur next -> handleFocusChange _rdcOnBlur _rdcOnBlurReq config next node
    Click p _
      | pointInEllipse p rdArea -> Just $ resultReqsEvts node reqs events
    KeyAction mod code KeyPressed
      | isSelectKey code -> Just $ resultReqsEvts node reqs events
    _ -> Nothing
    where
      rdArea = getRadioArea wenv node config
      path = node ^. L.info . L.path
      isSelectKey code = isKeyReturn code || isKeySpace code
      events = fmap ($ option) (_rdcOnChange config)
      setValueReq = widgetDataSet field option
      reqs = setValueReq ++ _rdcOnChangeReq config

  getSizeReq wenv node = req where
    theme = activeTheme wenv node
    width = fromMaybe (theme ^. L.radioWidth) (_rdcWidth config)
    req = (fixedSize width, fixedSize width)

  render wenv node renderer = do
    renderRadio renderer radioBW radioArea fgColor

    when (value == option) $
      renderMark renderer radioBW radioArea fgColor
    where
      model = _weModel wenv
      value = widgetDataGet model field
      radioArea = getRadioArea wenv node config
      radioBW = max 1 (_rW radioArea * 0.1)
      style_ = activeStyle_ (activeStyleConfig radioArea) wenv node
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

activeStyleConfig :: Rect -> ActiveStyleCfg s e
activeStyleConfig radioArea = def &
  L.isHovered .~ isNodeHoveredEllipse_ radioArea