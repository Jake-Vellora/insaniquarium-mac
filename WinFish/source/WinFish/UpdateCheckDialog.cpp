#include <string>

#include "UpdateCheckDialog.h"
#include "WinFishApp.h"
#include "UpdateCheck.h"

using namespace Sexy;

Sexy::UpdateCheckDialog::UpdateCheckDialog(Image* theComponentImage, Image* theButtonComponentImage, Image* theWaitImage, int theId) :
	Dialog(theComponentImage, theButtonComponentImage, theId, true, gSexyApp->GetString("UPDATE_CHECK_TITLE"),
		gSexyApp->GetString("UPDATE_CHECK_BODY"), gSexyApp->GetString("DIALOG_BUTTON_CANCEL"), BUTTONS_FOOTER)
{
	mWaitBarImage = theWaitImage;
	mCheckFinished = 0;
	mWaitBarXOffset = 0;
	mYOffset = 66;
}

Sexy::UpdateCheckDialog::~UpdateCheckDialog()
{
	// If the dialog is torn down while a check is still in flight, drop it so a
	// late completion handler can't fire a result dialog into a dead screen.
	UpdateCheck::Cancel();
}

void Sexy::UpdateCheckDialog::Update()
{
	Dialog::Update();

	// Animate the "contacting..." wait bar while the check is in flight.
	if (!mCheckFinished && mUpdateCnt % 3 == 0)
	{
		mWaitBarXOffset = (mWaitBarXOffset + 1) % 32;
		MarkDirty();
	}

	if (mCheckFinished)
		return;

	UpdateCheck::State aState = UpdateCheck::Poll();
	if (aState == UpdateCheck::IDLE || aState == UpdateCheck::PENDING)
		return; // still contacting GitHub - keep spinning

	mCheckFinished = true;

	// OK + a newer tag than we have installed -> offer the update. Anything else
	// (up to date, no release yet, or a transient/offline FAILED) degrades
	// silently to "up to date" - no scary error for a routine background check.
	bool anUpdateAvailable = false;
	if (aState == UpdateCheck::OK)
	{
		std::string aLatest = UpdateCheck::LatestTag();
		anUpdateAvailable = !aLatest.empty() && aLatest != UpdateCheck::InstalledTag();
	}

	Dialog* aDia = NULL;
	if (anUpdateAvailable)
		aDia = ((WinFishApp*)gSexyApp)->DoDialog(mId + 10000, true, gSexyApp->GetString("NEW_VERSION_TITLE"),
			gSexyApp->GetString("NEW_VERSION_BODY"), "", BUTTONS_YES_NO);
	else
		aDia = ((WinFishApp*)gSexyApp)->DoDialog(mId + 20000, true, gSexyApp->GetString("UP_TO_DATE_TITLE"),
			gSexyApp->GetString("UP_TO_DATE_BODY"), gSexyApp->GetString("DIALOG_BUTTON_OK"), BUTTONS_FOOTER);

	if (aDia)
		aDia->Move(mX + 32, mY - 32);

	// Remove this "contacting..." spinner (its frame AND its Cancel button) now
	// that the result is up, so nothing stacks behind it. Safe to do from our own
	// Update(): KillDialog defers the actual delete (SafeDeleteWidget), and
	// WidgetContainer::RemoveWidget advances the update iterator when it erases
	// the widget currently being updated.
	gSexyApp->KillDialog(mId);
}

void Sexy::UpdateCheckDialog::Draw(Graphics* g)
{
	Dialog::Draw(g);

	Rect aClipRect = Rect(mContentInsets.mLeft + 24, mHeight - mYOffset - mContentInsets.mBottom,
		mWidth - mContentInsets.mRight - mContentInsets.mLeft - 48, 16);

	Graphics g2(*g);

	g2.ClipRect(aClipRect);

	int aNumTiles = (aClipRect.mWidth / mWaitBarImage->GetWidth()) + 2;
	int aX = 0;
	for (int i = 0; i < aNumTiles; i++)
	{
		g2.DrawImage(mWaitBarImage, aX - mWaitBarXOffset + aClipRect.mX,aClipRect.mY);
		aX += mWaitBarImage->GetWidth();
	}

	g->SetColor(Color::Black);
	g->DrawRect(aClipRect.mX - 1, aClipRect.mY - 1, aClipRect.mWidth + 1, aClipRect.mHeight + 1);
}

int Sexy::UpdateCheckDialog::GetPreferredHeight(int theWidth)
{
	return Dialog::GetPreferredHeight(theWidth) + 32;
}

