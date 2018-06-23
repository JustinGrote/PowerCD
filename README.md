# PowerCD

This project's goal is to deliver a continuous deployment framework that anyone can use to build powershell modules to be published on the Powershell Gallery

This will provide a "Getting Started" process to building powershell modules, and will automate as much as possible all the dirty stuff such as building, testing, and deployment/publishing

"The beauty of standards is that there are so many to choose from"

I wanted to create a standard methodology to build powershell modules, as the options when I was getting started were bewildering and there was no comprehensive guide or solution.

First Release Goal:
- Provide an Invoke-Build process that supports two scenarios:
1. Open Source with Visual Studio Code, GitHub, PSGallery, Appveyor
2. Local Build with no Internet Access

- Make the build process have all external internet-connected dependencies optional, so you can just build locally/privately if you want with nothing more than a local git repository

- Make the process build once, run anywhere for minimum following platofmrs
1. Windows with Powershell v5+
2. Windows with Powershell Core v6.0.1+
3. Linux with Powershell Core v6.0.1+
4. <Maybe> MacOS with Powershell Core v6.0.1+

Second Release Goal:
- Provide a Plaster template for generating the initial module continuous deployment framework

Third Release Goal:
- Add support for VSTS integration (beyond just the GIT repository)

This project uses inspiration and some code from [ZLoeber's ModuleBuild](https://github.com/zloeber/ModuleBuild)