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

#ifndef __PROJECTILE_H__
#define __PROJECTILE_H__

#include <cstdint>
#include "../ConstEnums.h"
#include "GameObject.h"

class Plant;
class Zombie;
namespace Sexy
{
    class Graphics;
};
using namespace Sexy;

class ProjectileDefinition
{
public:
    ProjectileType          mProjectileType;
    int32_t                 mImageRow;
    int32_t                 mDamage;
};
extern ProjectileDefinition gProjectileDefinition[NUM_PROJECTILES];  //0x69F1C0

class Projectile : public GameObject
{
public:
    int32_t                 mFrame;                 //+0x24
    int32_t                 mNumFrames;             //+0x28
    int32_t                 mAnimCounter;           //+0x2C
    float                   mPosX;                  //+0x30
    float                   mPosY;                  //+0x34
    float                   mPosZ;                  //+0x38
    float                   mVelX;                  //+0x3C
    float                   mVelY;                  //+0x40
    float                   mVelZ;                  //+0x44
    float                   mAccZ;                  //+0x48
    float                   mShadowY;               //+0x4C
    bool                    mDead;                  //+0x50
    int32_t                 mAnimTicksPerFrame;     //+0x54
    ProjectileMotion        mMotionType;            //+0x58
    ProjectileType          mProjectileType;        //+0x5C
    int32_t                 mProjectileAge;         //+0x60
    int32_t                 mClickBackoffCounter;   //+0x64
    float                   mRotation;              //+0x68
    float                   mRotationSpeed;         //+0x6C
    bool                    mOnHighGround;          //+0x70
    int32_t                 mDamageRangeFlags;      //+0x74
    int32_t                 mHitTorchwoodGridX;     //+0x78
    AttachmentID            mAttachmentID;          //+0x7C
    float                   mCobTargetX;            //+0x80
    int32_t                 mCobTargetRow;          //+0x84
    ZombieID                mTargetZombieID;        //+0x88
    int32_t                 mLastPortalX;           //+0x8C

public:
    Projectile();
    ~Projectile();

    void                    ProjectileInitialize(int theX, int theY, int theRenderOrder, int theRow, ProjectileType theProjectileType);
    void                    Update();
    void                    Draw(Graphics* g);
    void                    DrawShadow(Graphics* g);
    void                    Die();
    void                    DoImpact(Zombie* theZombie);
    void                    UpdateMotion();
    void                    CheckForCollision();
    Zombie*                 FindCollisionTarget();
    void                    UpdateLobMotion();
    void                    CheckForHighGround();
    bool                    CantHitHighGround();
    void                    DoSplashDamage(Zombie* theZombie);
    ProjectileDefinition&   GetProjectileDef();
    unsigned int            GetDamageFlags(Zombie* theZombie/* = nullptr*/);
    Rect                    GetProjectileRect();
    void                    UpdateNormalMotion();
    Plant*                  FindCollisionTargetPlant();
    void                    ConvertToFireball(int theGridX);
    void                    ConvertToPea(int theGridX);
    bool                    IsSplashDamage(Zombie* theZombie/* = nullptr*/);
    void                    PlayImpactSound(Zombie* theZombie);
    bool                    IsZombieHitBySplash(Zombie* theZombie);
    bool                    PeaAboutToHitTorchwood();

};

#endif
