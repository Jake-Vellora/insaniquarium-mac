#include <SexyAppFramework/Font.h>

#include "MessageWidget.h"
#include "WinFishApp.h"
#include "Board.h"
#include "Res.h"

using namespace Sexy;

Sexy::MessageWidget::MessageWidget(WinFishApp* theApp, SexyString theMessage)
{
	mUnusedInt = 0;
	mColor1 = Color(0xb4, 0xfa, 0x5a, 0xff);
	mColor2 = Color(0, 0x4b, 0, 0xff);
	mApp = theApp;
	mFont = FONT_CONTINUUMBOLD14OUTLINE;
	mMessage = theMessage;
	mX = 90;
	mY = 445;
	mWidth = 460;
	mHeight = mFont->GetHeight() + 6;
	mMessageTimer = 185;
	mMouseVisible = false;
	mMessageId = -1;
	mIsBlinking = false;
}

Sexy::MessageWidget::~MessageWidget()
{
}

void Sexy::MessageWidget::Update()
{
	Board* aBoard = mApp->mBoard;
	if (aBoard && !aBoard->mPause && mMessageTimer > 0)
		mMessageTimer--;
}

void Sexy::MessageWidget::Draw(Graphics* g)
{
	if (mMessageTimer <= 0)
		return;

	int aFontHeight = mFont->GetHeight();
	int aHeight = mHeight;
	int aFontAscent = mFont->GetAscent();

	int aY = aFontAscent + (aHeight - aFontHeight) / 2;

	int aStrWidth = mFont->StringWidth(mMessage);
	int aX = (mWidth - aStrWidth) / 2 + 2;

	int aTimer = mMessageTimer % 32;

	if (aTimer < 27 || !mIsBlinking)
	{
		g->SetColor(mColor2);
		g->SetFont(mFont);
		g->DrawString(mMessage, aX, aY);
		g->SetColor(mColor1);
		g->SetFont(FONT_CONTINUUMBOLD14);
		g->DrawString(mMessage, aX, aY);
	}
}

void Sexy::MessageWidget::Sync(DataSync& theSync)
{
	theSync.SyncString(mMessage);
	theSync.SyncColor(mColor1);
	theSync.SyncColor(mColor2);
	theSync.SyncLong(mUnusedInt);
	theSync.SyncLong(mMessageTimer);
	theSync.SyncBool(mIsBlinking);
	theSync.SyncLong(mMessageId);
}
