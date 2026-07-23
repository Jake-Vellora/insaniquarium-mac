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

#ifndef __LAWNMOWER_H__
#define __LAWNMOWER_H__

#include <cstdint>
#include "../ConstEnums.h"
#include "misc/Rect.h"

class LawnApp;
class Board;
class Zombie;
namespace Sexy
{
    class Graphics;
};
using namespace Sexy;

class LawnMower
{
public:
    LawnApp*            mApp;                   //+0x0
    Board*              mBoard;                 //+0x4
    float               mPosX;                  //+0x8
    float               mPosY;                  //+0xC
    int32_t             mRenderOrder;           //+0x10
    int32_t             mRow;                   //+0x14
    int32_t             mAnimTicksPerFrame;     //+0x18
    ReanimationID       mReanimID;              //+0x1C
    int32_t             mChompCounter;          //+0x20
    int32_t             mRollingInCounter;      //+0x24
    int32_t             mSquishedCounter;       //+0x28
    LawnMowerState      mMowerState;            //+0x2C
    bool                mDead;                  //+0x30
    bool                mVisible;               //+0x31
    LawnMowerType       mMowerType;             //+0x34
    float               mAltitude;              //+0x38
    MowerHeight         mMowerHeight;           //+0x3C
    int32_t             mLastPortalX;           //+0x40

public:
    void                LawnMowerInitialize(int theRow);
    void                StartMower();
    void                Update();
    void                Draw(Graphics* g);
    void                Die();
    Rect                GetLawnMowerAttackRect();
    void                UpdatePool();
    void                MowZombie(Zombie* theZombie);
    void                SquishMower();
    /*inline*/ void     EnableSuperMower(bool theEnable);
};

#endif
