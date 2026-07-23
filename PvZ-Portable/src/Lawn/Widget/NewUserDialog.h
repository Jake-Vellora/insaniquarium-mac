/*
 * Copyright (C) 2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * SPDX-License-Identifier: LGPL-3.0-or-later
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

#ifndef __NEWUSERDIALOG_H__
#define __NEWUSERDIALOG_H__

#include "LawnDialog.h"
#include "widget/EditListener.h"

class NewUserDialog : public LawnDialog, public EditListener
{
public:
	LawnApp*			mApp;					//+0x170
	EditWidget*			mNameEditWidget;		//+0x174

public:
	NewUserDialog(LawnApp* theApp, bool isRename);
	virtual ~NewUserDialog();

	virtual int			GetPreferredHeight(int theWidth);
	virtual void		Resize(int theX, int theY, int theWidth, int theHeight);
	virtual void		AddedToManager(WidgetManager* theWidgetManager);
	virtual void		RemovedFromManager(WidgetManager* theWidgetManager);
	virtual void		Draw(Graphics* g);
	virtual void		EditWidgetText(int theId, const std::string& theString);
	virtual bool		AllowChar(int, char theChar);
	std::string			GetName();
	void				SetName(const std::string& theName);
};

#endif
