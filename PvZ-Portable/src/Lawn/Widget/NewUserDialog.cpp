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

#include "NewUserDialog.h"
#include "../../LawnApp.h"
#include "../../Resources.h"
#include "widget/WidgetManager.h"

//0x45D610
// GOTY @Patoke: 0x460F20
NewUserDialog::NewUserDialog(LawnApp* theApp, bool isRename) : LawnDialog(
	theApp, 
	isRename ? Dialogs::DIALOG_RENAMEUSER : Dialogs::DIALOG_CREATEUSER, 
	true, 
	// @Patoke: these locals don't exist
	isRename ? "RENAME USER" : "NEW USER", 
	"Please enter your name:", 
	"[DIALOG_BUTTON_OK]", 
	Dialog::BUTTONS_OK_CANCEL)
{
	mApp = theApp;
	mVerticalCenterText = false;
	mNameEditWidget = CreateEditWidget(0, this, this);
	mNameEditWidget->mMaxChars = 12;
	mNameEditWidget->AddWidthCheckFont(FONT_BRIANNETOD16, 220);
	CalcSize(110, 40);
}

//0x45D7E0 and 0x45D800
NewUserDialog::~NewUserDialog()
{
	delete mNameEditWidget;
}

//0x45D870
void NewUserDialog::AddedToManager(WidgetManager* theWidgetManager)
{
	LawnDialog::AddedToManager(theWidgetManager);
	AddWidget(mNameEditWidget);
	theWidgetManager->SetFocus(mNameEditWidget);
}

//0x45D8E0
void NewUserDialog::RemovedFromManager(WidgetManager* theWidgetManager)
{
	LawnDialog::RemovedFromManager(theWidgetManager);
	RemoveWidget(mNameEditWidget);
}

int NewUserDialog::GetPreferredHeight(int theWidth)
{
	return LawnDialog::GetPreferredHeight(theWidth) + 40;
}

//0x45D910
void NewUserDialog::Resize(int theX, int theY, int theWidth, int theHeight)
{
	LawnDialog::Resize(theX, theY, theWidth, theHeight);
	mNameEditWidget->Resize(mContentInsets.mLeft + 12, mHeight - 155, mWidth - mContentInsets.mLeft - mContentInsets.mRight - 24, 28);
}

//0x45D970
void NewUserDialog::Draw(Graphics* g)
{
	LawnDialog::Draw(g);
	DrawEditBox(g, mNameEditWidget);
}

//0x45D9D0
void NewUserDialog::EditWidgetText(int theId, const std::string& theString)
{
	(void)theId;(void)theString;
	mApp->ButtonDepress(mId + 2000);
}

//0x45D9F0
bool NewUserDialog::AllowChar(int, char theChar)
{
	return isalnum(theChar) || theChar == ' ';
}

//0x45DA20
std::string NewUserDialog::GetName()
{
	std::string aString;
	char aLastChar = ' ';

	for (size_t i = 0; i < mNameEditWidget->mString.size(); i++)
	{
		char aChar = mNameEditWidget->mString[i];
		if (aChar != ' ')
		{
			aString.append(1, aChar);
		}
		else if (aChar != aLastChar)
		{
			aString.append(1, ' ');
		}

		aLastChar = aChar;
	}

	if (aString.size() && aString[aString.size() - 1] == ' ')
	{
		aString.resize(aString.size() - 1);
	}

	return aString;
}

void NewUserDialog::SetName(const std::string& theName)
{
	mNameEditWidget->SetText(theName, true);
	mNameEditWidget->mCursorPos = theName.size();
	mNameEditWidget->mHilitePos = 0;
}
