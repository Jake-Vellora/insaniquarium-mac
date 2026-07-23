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

#ifndef __CUTSCENE_H__
#define __CUTSCENE_H__

#include "misc/KeyCodes.h"
#include "Zombie.h"

using namespace Sexy;
class LawnApp;
class Board;
class ChallengeScreen;

class CutScene
{
public:
    LawnApp*                    mApp;                             //+0x0
    Board*                      mBoard;                           //+0x4
    int                         mCutsceneTime;                    //+0x8
    int                         mSodTime;                         //+0xC
    int                         mGraveStoneTime;                  //+0x10
    int                         mReadySetPlantTime;               //+0x14
    int                         mFogTime;                         //+0x18
    int                         mBossTime;                        //+0x1C
    int                         mCrazyDaveTime;                   //+0x20
    int                         mLawnMowerTime;                   //+0x24
    int                         mCrazyDaveDialogStart;            //+0x28
    bool                        mSeedChoosing;                    //+0x2C
    ReanimationID               mZombiesWonReanimID;              //+0x30
    bool                        mPreloaded;                       //+0x34
    bool                        mPlacedZombies;                   //+0x35
    bool                        mPlacedLawnItems;                 //+0x36
    int                         mCrazyDaveCountDown;              //+0x38 Countdown for Crazy Dave's upsell dialog
    int                         mCrazyDaveLastTalkIndex;          //+0x3C Index of Crazy Dave's upsell dialog lines
    bool                        mUpsellHideBoard;                 //+0x40 Whether to hide the board during upsell
    ChallengeScreen*            mUpsellChallengeScreen;           //+0x44 The challenge screen inserted during upsell
    bool                        mPreUpdatingBoard;                //+0x48 Whether the board is pre-updating during scene setup
	std::vector<std::string> mLoadedResourceNames;

public:
    CutScene();
    ~CutScene();

    void                        StartLevelIntro();
    void                        CancelIntro();
    void                        Update();
    void                        AnimateBoard();
    /*inline*/ void             StartSeedChooser();
    /*inline*/ void             EndSeedChooser();
    /*inline*/ int              CalcPosition(int theTimeStart, int theTimeEnd, int thePositionStart, int thePositionEnd);
    void                        PlaceStreetZombies();
    void                        AddGraveStoneParticles();
    void                        PlaceAZombie(ZombieType theZombieType, int theGridX, int theGridY);
    bool                        CanZombieGoInGridSpot(ZombieType theZombieType, int theGridX, int theGridY, bool theZombieGrid[5][5]);
    /*inline*/ bool             IsSurvivalRepick();
    /*inline*/ bool             IsAfterSeedChooser();
    void                        AddFlowerPots();
    void                        UpdateZombiesWon();
    void                        StartZombiesWon();
    /*inline*/ bool             ShowZombieWalking();
    /*inline*/ bool             IsCutSceneOver();
    void                        ZombieWonClick();
    void                        MouseDown(int theX, int theY);
    void                        KeyDown(KeyCode theKey);
    /*inline*/ void             AdvanceCrazyDaveDialog(bool theJustSkipping);
    void                        ShowShovel();
    bool                        CanGetPacketUpgrade();
    bool                        CanGetPacketUpgrade(int theIndex);
    void                        FindPlaceForStreetZombies(ZombieType theZombieType, bool theZombieGrid[5][5], int& thePosX, int& thePosY);
    void                        FindAndPlaceZombie(ZombieType theZombieType, bool theZombieGrid[5][5]);
    static /*inline*/ bool      Is2x2Zombie(ZombieType theZombieType);
    void                        PreloadResources();
    /*inline*/ bool             IsBeforePreloading();
    /*inline*/ bool             IsShowingCrazyDave();
    bool                        IsNonScrollingCutscene();
    bool                        IsScrolledLeftAtStart();
    /*inline*/ bool             IsInShovelTutorial();
    void                        PlaceLawnItems();
    bool                        CanGetSecondPacketUpgrade();
    int                         ParseDelayTimeFromMessage();
    int                         ParseTalkTimeFromMessage();
    void                        ClearUpsellBoard();
    void                        LoadIntroBoard();
    /*inline*/ void             AddUpsellZombie(ZombieType theZombieType, int thePixelX, int theGridY);
    void                        LoadUpsellBoardPool();
    void                        LoadUpsellBoardFog();
    void                        LoadUpsellChallengeScreen();
    void                        LoadUpsellBoardRoof();
    void                        UpdateUpsell();
    void                        DrawUpsell(Graphics* g);
    void                        UpdateIntro();
    void                        DrawIntro(Graphics* g);
    /*inline*/ bool             ShouldRunUpsellBoard();
};

#endif
