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

#ifndef __USERDIALOG_H__
#define __USERDIALOG_H__

#include "LawnDialog.h"
#include "widget/ListListener.h"
#include "widget/EditListener.h"

namespace Sexy
{
	class ListWidget;
};

class UserDialog : public LawnDialog, public ListListener, public EditListener
{
protected:
	enum
	{
		UserDialog_RenameUser,
		UserDialog_DeleteUser
	};

public:
	ListWidget*			mUserList;				//+0x174
	DialogButton*		mRenameButton;			//+0x178
	DialogButton*		mDeleteButton;			//+0x17C
	int					mNumUsers;				//+0x180

public:
	UserDialog(LawnApp* theApp);
	virtual ~UserDialog();

	virtual void		Resize(int theX, int theY, int theWidth, int theHeight);
	virtual int			GetPreferredHeight(int theWidth);
	virtual void		AddedToManager(WidgetManager* theWidgetManager);
	virtual void		RemovedFromManager(WidgetManager* theWidgetManager);
	virtual void 		ListClicked(int theId, int theIdx, int theClickCount);
	virtual void 		ListClosed(int){}
	virtual void 		ListHiliteChanged(int, int, int){}
	virtual void		ButtonDepress(int theId);
	virtual void		EditWidgetText(int theId, const std::string& theString);
	virtual bool		AllowChar(int theId, char theChar);
	virtual void		Draw(Graphics* g);
	void				FinishDeleteUser();
	void				FinishRenameUser(const std::string& theNewName);
	std::string			GetSelName();
};

#endif
