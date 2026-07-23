#ifndef __VIRTUALDIALOG_H__
#define __VIRTUALDIALOG_H__

#include "MoneyDialog.h"

namespace Sexy
{
	class BubbleMgr;

	class VirtualDialog : public MoneyDialog
	{
	public:
		BubbleMgr*				mBubbleMgr;
		Rect					mFishBoxRect;

	public:
		VirtualDialog(WinFishApp* theApp);
		virtual ~VirtualDialog();

		virtual void			Update();
		virtual void			Draw(Graphics* g);
		virtual void			Resize(int theX, int theY, int theWidth, int theHeight);
	};
}

#endif
