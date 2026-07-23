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

// ScrollbarWidget.h: interface for the ScrollbarWidget class.
//
//////////////////////////////////////////////////////////////////////

#ifndef __SCROLLBARWIDGET_H__
#define __SCROLLBARWIDGET_H__

#include "Widget.h"
#include "ButtonListener.h"

namespace Sexy 
{

class ScrollListener;
class ScrollbuttonWidget;

class ScrollbarWidget : public Widget, public ButtonListener 
{
public:

enum 
{
	UPDATE_MODE_IDLE		=0,
	UPDATE_MODE_PGUP,
	UPDATE_MODE_PGDN
};		

public:

	ScrollbuttonWidget		*mUpButton;
	ScrollbuttonWidget		*mDownButton;

	bool					mInvisIfNoScroll;			

public:

	int						mId;

	double					mValue;
	double					mMaxValue;
	double					mPageSize;
	bool					mHorizontal;

	bool					mPressedOnThumb;
	int						mMouseDownThumbPos;
	int						mMouseDownX;
	int						mMouseDownY;

	int						mUpdateMode;
	int						mUpdateAcc;
	int						mButtonAcc;
	int						mLastMouseX;
	int						mLastMouseY;
	ScrollListener*			mScrollListener;

public:
	ScrollbarWidget(int theId, ScrollListener *theScrollListener);
	virtual ~ScrollbarWidget();

	virtual void			SetInvisIfNoScroll(bool invisIfNoScroll);
	virtual void			SetMaxValue(double theNewMaxValue);
	virtual void			SetPageSize(double theNewPageSize);
	virtual void			SetValue(double theNewValue);
	virtual void			SetHorizontal(bool isHorizontal);

	virtual void			ResizeScrollbar(int theX, int theY, int theWidth, int theHeight);			
	virtual bool			AtBottom();
	virtual void			GoToBottom();
	virtual void			DrawThumb(Graphics *g, int theX, int theY, int theWidth, int theHeight);
	virtual int				GetTrackSize();
	virtual int				GetThumbSize();
	virtual int				GetThumbPosition();
	virtual void			Draw(Graphics *g);
	virtual void			ClampValue();
	virtual void			SetThumbPosition(int thePosition);
	virtual void			ButtonPress(int theId);
	virtual void			ButtonDepress(int theId);
	virtual void			ButtonDownTick(int theId);
	virtual void			Update();
	virtual int				ThumbCompare(int x, int y);
	virtual void			MouseDown(int x, int y, int theClickCount) { Widget::MouseDown(x, y, theClickCount); }
	virtual void			MouseDown(int x, int y, int theBtnNum, int theClickCount);
	virtual void			MouseUp(int x, int y) { Widget::MouseUp(x, y); }
	virtual void			MouseUp(int x, int y, int theBtnNum, int theClickCount);
	virtual void			MouseDrag(int x, int y);
};

}

#endif // __SCROLLBARWIDGET_H__
