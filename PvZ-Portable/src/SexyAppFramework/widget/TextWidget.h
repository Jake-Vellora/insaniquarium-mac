/*
 * Portions of this file are based on the PopCap Games Framework
 * Copyright (C) 2005-2009 PopCap Games, Inc.
 * 
 * Copyright (C) 2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later AND LicenseRef-PopCap
 *
 * This file is part of PvZ-Portable.
 *
 * PvZ-Portable is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PvZ-Portable is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with PvZ-Portable. If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef __TEXTWIDGET_H__
#define __TEXTWIDGET_H__

#include "Widget.h"
#include "ScrollListener.h"

namespace Sexy
{

class ScrollbarWidget;
class _Font;

typedef std::vector<std::string> SexyStringVector;
typedef std::vector<int> IntVector;

class TextWidget : public Widget, public ScrollListener
{
public:
	_Font*				mFont;
	ScrollbarWidget*	mScrollbar;
	
	SexyStringVector	mLogicalLines;
	SexyStringVector	mPhysicalLines;
	IntVector			mLineMap;
	double				mPosition;
	double				mPageSize;
	bool				mStickToBottom;
	int					mHiliteArea[2][2];
	int					mMaxLines;
	
public:
	TextWidget();

	virtual SexyStringVector GetLines();
	virtual void SetLines(SexyStringVector theNewLines);
	virtual void Clear();
	virtual void DrawColorString(Graphics* g, const std::string& theString, int x, int y, bool useColors);
	virtual void DrawColorStringHilited(Graphics* g, const std::string& theString, int x, int y, int theStartPos, int theEndPos);
	virtual int GetStringIndex(const std::string& theString, int thePixel);
	
	virtual int GetColorStringWidth(const std::string& theString);
	virtual void Resize(int theX, int theY, int theWidth, int theHeight);
	virtual Color GetLastColor(const std::string& theString);
	virtual void AddToPhysicalLines(int theIdx, const std::string& theLine);
	
	virtual void AddLine(const std::string& theString);
	virtual bool SelectionReversed();
	virtual void GetSelectedIndices(int theLineIdx, int* theIndices);
	virtual void Draw(Graphics* g);
	virtual void ScrollPosition(int theId, double thePosition);
	virtual void GetTextIndexAt(int x, int y, int* thePosArray);
	virtual std::string GetSelection();

	virtual void MouseDown(int x, int y, int theClickCount);
	virtual void MouseDrag(int x, int y);	
	
	virtual void KeyDown(KeyCode theKey);
};

}

#endif //__TEXTWIDGET_H__