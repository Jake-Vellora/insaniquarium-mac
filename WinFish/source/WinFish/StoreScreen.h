#ifndef __STORESCREEN_H__
#define __STORESCREEN_H__

#include "SexyAppFramework/Widget.h"
#include "SexyAppFramework/ButtonListener.h"

namespace Sexy
{
	class WinFishApp;
	class StoreButtonWidget;
	class MyLabelWidget;
	class DialogButton;
	class StoreScreenOverlay;
	class GameObject;
	class Fish;

	class StoreScreen : public Widget, public ButtonListener
	{
	public:
		WinFishApp* mApp;
		int m0x90;
		StoreScreenOverlay* mOverlay;
		DialogButton* mBackButton;
		StoreButtonWidget* mStoreButtons[8];
		StoreButtonWidget* mStoreButtonLast;
		MyLabelWidget* mShellsLabel;
		SexyString mShellsString;
		int mStoreButtonsX;
		int mStoreButtonsXGap;
		int mMerylBlinkTimer;
		MTRand mRand;
		long long mSeedBase;
		int mBoughtItemTimer;
		bool mSaveData;
		int mOverButtonId;
		int mStoreScreenUpdateCnt;

		enum ProductTypes
		{
			PRODUCT_SOLD,
			PRODUCT_FISH,
			PRODUCT_BUBBULATOR,
			PRODUCT_BACKDROP,
			PRODUCT_ALIEN_ATTRACTOR,
			PRODUCT_UPGRADE
		};

	public:
		StoreScreen(WinFishApp* theApp);
		virtual ~StoreScreen();

		virtual void			AddedToManager(WidgetManager* theWidgetManager);
		virtual void			RemovedFromManager(WidgetManager* theWidgetManager);
		virtual void			Update();
		virtual void			OrderInManagerChanged();
		virtual void			DrawOverlay(Graphics* g);
		virtual void			MouseEnter();
		virtual void			MouseMove(int theX, int theY);

		virtual void			ButtonPress(int theId);
		virtual void			ButtonDepress(int theId);

		GameObject*				ConfirmPurchase();
		void					InitializeStoreButtons(int theSeed);
		void					CommonFishStoreSlots();
		void					ColorfulFishStoreSlots();
		void					SpecialFishStoreSlots();
		void					ItemsStoreSlots();
		bool					IsSpecialFishInTank(int theSpecialFishId);
		void					InitFishColors(Fish* theFish, bool randomColors);
		GameObject*				GetRandomSpecialFish(bool possibleClassicFish, int theSkipType, int unk2);
		Fish*					RandomGuppyOrOscar();
		bool					IsSpecialFishAllowed(int unk, int theType);
		int						Unk01(bool deterministic);
		GameObject*				GetSpecial8Fish();
		Fish*					MakeSpecialFish(int theId);
		void					SetUpSpecialFish(GameObject* theObject, bool deterministic);
		void					SpecialId5SetUp(GameObject* theObject);
		void					SpecialId6SetUp(GameObject* theObject);
		void					SpecialId78SetUp(GameObject* theObject);
		bool					IsSpecialFishValid(GameObject* theObject);
	};

	class StoreScreenOverlay : public Widget
	{
	public:
		StoreScreen* mScreen;

	public:
		virtual void			Draw(Graphics* g);
	};
}

#endif