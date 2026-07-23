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

#ifndef __ACHIEVEMENTSSCREEN_H__
#define __ACHIEVEMENTSSCREEN_H__
// @Patoke: implement file

#include "../../ConstEnums.h"
#include "widget/Widget.h"

class LawnApp;

using namespace Sexy;

enum AchievementId {
	HomeSecurity, //
	NovelPeasPrize, //
	BetterOffDead, //
	ChinaShop, //
	Spudow, //
	Explodonator, //
	Morticulturalist, //
	DontPea, //
	RollSomeHeads, //
	Grounded, //
	Zombologist, //
	PennyPincher, //
	SunnyDays, //
	PopcornParty, //
	GoodMorning, //
	NoFungusAmongUs, //
	BeyondTheGrave, //
	Immortal, //
	ToweringWisdom, //
	MustacheMode, //
    MAX_ACHIEVEMENTS
};

// todo @Patoke: add these
class AchievementItem {
public:
    std::string name;
    std::string description;
};

extern AchievementItem gAchievementList[MAX_ACHIEVEMENTS];

class AchievementsWidget : public Widget {
public:
	LawnApp*	mApp;                       //+GOTY @Patoke: 0xA8
	int			mScrollDirection;			//+GOTY @Patoke: 0xAC
	Rect		mMoreRockRect;				//+GOTY @Patoke: 0xC0
	int			mScrollValue;				//+GOTY @Patoke: 0xB0
	int			mScrollDecay;				//+GOTY @Patoke: 0xB4
	int			mDefaultScrollValue;		//+GOTY @Patoke: 0xB8
	bool		mDidPressMoreButton;		//+GOTY @Patoke: 0xBC

	AchievementsWidget(LawnApp* theApp);
	virtual ~AchievementsWidget();

	virtual void                Update();
	virtual void                Draw(Graphics* g);
	virtual void                KeyDown(KeyCode theKey);
	virtual void                MouseDown(int x, int y, int theClickCount);
	virtual void                MouseUp(int x, int y, int theClickCount);
	virtual void				MouseWheel(int theDelta);
};

class ReportAchievement {
public:
	static void GiveAchievement(LawnApp* theApp, int theAchievement, bool theForceGive);
	static void AchievementInitForPlayer(LawnApp* theApp);
};

#endif