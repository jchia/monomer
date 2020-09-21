{-# LANGUAGE MultiParamTypeClasses #-}

module Monomer.Widget.Widgets.WidgetCombinators where

import Control.Lens (ALens')

import Monomer.Widget.Types

class ValidInput a s where
  validInput :: ALens' s Bool -> a

class MaxLengthCombinator a where
  maxLength :: Int -> a

class OnChange a where
  onChange :: [v -> e] -> a

class OnChangeReq a where
  onChangeReq :: [WidgetRequest s] -> a
