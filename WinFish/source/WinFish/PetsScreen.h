#ifndef __PETSSCREEN_H__
#define __PETSSCREEN_H__

#include <SexyAppFramework/Widget.h>
#include <SexyAppFramework/ButtonListener.h>

namespace Sexy
{
	class WinFishApp;
	class MemoryImage;
	class PetButtonWidget;
	class DialogButton;
	class PetScreenOverlay;

	class PetsScreen : public Widget, public ButtonListener
	{
	public:
		WinFishApp* mApp;
		DialogButton* mReturnButton;
		DialogButton* mMenuButton;
		PetScreenOverlay* mOverlay;
		PetButtonWidget* mPetButtons[24];
		MemoryImage* mBackgroundImage;
		bool m0x100[24];
		int m0x118;
		int m0x11c;
		int m0x120;
		int m0x124;
		int m0x128;
		int m0x12c;
		int m0x130;
		int m0x134;

	public:
		PetsScreen(WinFishApp* theApp);
		virtual ~PetsScreen();

		virtual void			AddedToManager(WidgetManager* theWidgetManager);
		virtual void			RemovedFromManager(WidgetManager* theWidgetManager);

		virtual void			Update();

		virtual void			DrawOverlay(Graphics* g);

		virtual void			ButtonPress(int theId);
		virtual void			ButtonDepress(int theId);
		virtual void			ButtonMouseEnter(int theId);
		virtual void			ButtonMouseLeave(int theId);

		void					DrawPetInfo(Graphics* g, int thePetId, int theAlpha);
	};

	class PetScreenOverlay : public Widget
	{
	public:
		PetsScreen* mScreen;

	public:
		virtual void			Draw(Graphics* g);

	};
}

#endif