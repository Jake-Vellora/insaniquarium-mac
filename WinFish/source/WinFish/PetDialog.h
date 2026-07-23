#ifndef __PETDIALOG_H__
#define __PETDIALOG_H__

#include "MoneyDialog.h"

namespace Sexy
{
	class WinFishApp;

	class PetDialog : public MoneyDialog
	{
	public:
		int m0x158;
		int m0x15c;
		Rect mRects[24];
		bool mPetsUnlocked[24];

	public:
		PetDialog(WinFishApp* theApp);
		virtual ~PetDialog();

		virtual void			Draw(Graphics* g);

		virtual void			Resize(int theX, int theY, int theWidth, int theHeight);
		virtual void			MouseLeave();
		virtual void			MouseMove(int x, int y);
		virtual void			MouseDown(int x, int y, int theClickCount);
		virtual void			MouseUp(int x, int y, int theClickCount);
		virtual bool			IsPointVisible(int x, int y);

		int						MouseAtHandle(int x, int y);

		virtual void			ButtonPress(int theId);
		virtual void			ButtonDepress(int theId);
	};
}

#endif
