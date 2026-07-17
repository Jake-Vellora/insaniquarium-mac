// M1 rendering spike: boot SexyAppBase, load a real Steam GIF+alpha pair,
// draw it over a magenta fill so mask edges are obvious.
#include <SexyAppFramework/SexyAppBase.h>
#include <SexyAppFramework/Widget.h>
#include <SexyAppFramework/WidgetManager.h>
#include <SexyAppFramework/Graphics.h>
#include <SexyAppFramework/Color.h>
#include <SexyAppFramework/GLImage.h>
#include <SDL2/SDL_main.h>

using namespace Sexy;

// Game code normally defines this (WinFish Res.cpp); spike stub only.
namespace Sexy { _Font* FONT_PICO129 = nullptr; }

class SpikeWidget : public Widget
{
public:
	GLImage* mImg;
	SpikeWidget(GLImage* theImg) : mImg(theImg) {}

	void Update() override
	{
		Widget::Update();
		MarkDirty();
	}

	void Draw(Graphics* g) override
	{
		g->SetColor(Color(255, 0, 255));
		g->FillRect(0, 0, mWidth, mHeight);
		if (mImg != nullptr)
			g->DrawImage(mImg, 40, 40);
	}
};

class SpikeApp : public SexyAppBase
{
public:
	SpikeWidget* mSpikeWidget = nullptr;

	void Init()
	{
		mTitle = "Insaniquarium Spike";
		mWidth = 640;
		mHeight = 480;
		mIsWindowed = true;
		mResourceDir = "/Users/jake/games/insaniquarium/";
		SexyAppBase::Init();
	}

	void LoadingThreadCompleted()
	{
		SexyAppBase::LoadingThreadCompleted();
		GLImage* aFish = GetImage("images/chomp");
		fprintf(stderr, "SPIKE: GetImage(images/chomp) = %p\n", (void*)aFish);
		if (aFish == nullptr)
		{
			aFish = GetImage("/Users/jake/games/insaniquarium/images/Chomp");
			fprintf(stderr, "SPIKE: GetImage(abs Chomp) = %p\n", (void*)aFish);
		}
		if (aFish != nullptr)
			fprintf(stderr, "SPIKE: image %dx%d\n", aFish->mWidth, aFish->mHeight);
		mSpikeWidget = new SpikeWidget(aFish);
		mSpikeWidget->Resize(0, 0, mWidth, mHeight);
		mWidgetManager->AddWidget(mSpikeWidget);
	}
};

int main(int argc, char* argv[])
{
	const char* dir = "/Users/jake/games/insaniquarium";
	Sexy::SetResourceFolder(dir);
	Sexy::ChDir(dir);

	SpikeApp* anApp = new SpikeApp();
	anApp->Init();
	anApp->Start();
	anApp->Shutdown();
	delete anApp;
	return 0;
}
