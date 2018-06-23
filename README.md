# PowerCD

This project's goal is to deliver a continuous deployment framework that anyone can use to build powershell modules to be published on the Powershell Gallery

This will provide a "Getting Started" process to building powershell modules, and will automate as much as possible all the dirty stuff such as building, testing, and deployment/publishing

"The beauty of standards is that there are so many to choose from"

I wanted to create a standard methodology to build powershell modules, as the options when I was getting started were bewildering and there was no comprehensive guide or solution.

## Release Goals

### Initial Release Goals
- Provide an Invoke-Build process that supports two scenarios:
1. Open Source with Visual Studio Code, GitHub, PSGallery, Appveyor
2. Local Build with no Internet Access

- Make the build process have all external internet-connected dependencies optional, so you can just build locally/privately if you want with nothing more than a local git repository

- Make the process build once, run anywhere for minimum following platofmrs
1. Windows with Powershell v5+
2. Windows with Powershell Core v6.0.1+
3. Linux with Powershell Core v6.0.1+
4. <Maybe> MacOS with Powershell Core v6.0.1+

- Provide a Plaster template for generating the initial module continuous deployment framework


This project uses inspiration and some code from [ZLoeber's ModuleBuild](https://github.com/zloeber/ModuleBuild)

## Design Decisions
Making a template that meets everyone's needs or preferences is nearly impossible, so instead this module's focus is on "smart defaults" and "prescriptive guidance" to help new module builders get a continuous deployment pipeline. Advanced users can fork or add whatever "plugins" they want to the XML to support their personal preferences.

I've tried to select products with broad support, especially within the Powershell Github repository itself, to ensure users have a good ecosystem of support.

I've also tried tried to ensure that projects will "build" on any Windows or Linux machine with full documentation/etc. without any external dependencies, so if you choose not to use Github/Appveyor/etc. and want to use PowerCD inside an organization with no internet access, you can.

### Prescriptive Module Layout and Organization
Based on RamblingCookieMonster's template plus what is seen in the community. (Public/Private/Lib)

### Prescriptive Services and Products
- Versioning Tool - [GitVersion](https://gitversion.readthedocs.io/en/latest/)
- Versioning Scheme - [Semantic Versioning](https://semver.org/)
- Build Tool - [Invoke-Build](https://github.com/nightroman/Invoke-Build). Only used for packaging/versioning, this plaster is primarily for script modules.
- Build Host - [Appveyor](https://www.appveyor.com/) ([Windows](https://www.appveyor.com/docs/) and [Linux](https://www.appveyor.com/docs/getting-started-with-appveyor-for-linux/))
- Code Testing Tool - [Pester](https://github.com/pester/Pester) and [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- Code Coverage Host - [CodeCov](https://codecov.io)
- Documentation - [PlatyPS](https://github.com/PowerShell/platyPS)
- Documentation Host - [ReadTheDocs](https://docs.readthedocs.io)
- Coding Process - [Git Flow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) where develop and master are always deployable
- Repository - [Git](https://git-scm.com/) (Local, [Github](https://github.com/), or [Visual Studio Team Services](https://visualstudio.microsoft.com/team-services/))
- Deploy Targets
    - Local (Release Folder .zip)
    - [GitHub Releases](https://help.github.com/articles/about-releases/),
    - [Powershell Gallery](https://www.powershellgallery.com/)
    - [VSTS Package Feeds (https://docs.microsoft.com/en-us/vsts/package/overview?view=vsts)
    - Any repository supported by Publish-Module.

### FAQs / Whatabouts

*What about Travis?*

Appveyor added Linux support in May 2018 and it works, so we use that for PowerCD builds as the default to keep it consistent. You can always add a Travis build later

*What about OSX builds and testing?*

Will add Travis support to do this later, right now focus is just on WindowsPowershell and Powershell Core builds on Windows and Linux (ubuntu as test target)

*Why not a /src directory?*

Powershell script modules by default in my opinion should usable with import-module from a direct "git checkout" of the source, even if the versioning is inaccurate (because it is dynamically determined by GitVersion at build time). Organizing things into a /src directory would defeat that purpose/goal especially since Powershell doesn't need to be "compiled" like C#, it is an interpreted language.

*What about Binary Modules?*

This template is targeted for people new to module building, so they probably aren't building .NET-based modules, maybe included a .NET library here or there in /lib. Binary Module support is on the way-later roadmap.

*Why not PSake?*

While PSake is more popular, Invoke-Build has sufficient improvements and Powershell Team support, as well as better portability.

This plaster is designed so that someone who is new to building modules doesn't have to touch the build script, they just have to place things into Private, Public, and lib, so it's less important for them to have intimate knowledge of the build script, especially since all it primarily does currently is release management and versioning automation, not actual "building/compiling" of code.

*Why CodeCov? Why not Coveralls?*

CodeCov is what the [official Powershell Core repository uses](https://codecov.io/gh/PowerShell/PowerShell), plus I think the reports look cleaner.

*What about Bitbucket?*

Low demand and trying to keep the compatibility matrix small. If you're concerned about Microsoft buying Github, well, Powershell Core is on Github, so I guess you'll stop using that too right?

*Why don't you call this Continuous Deployment?*

The function of this module is to publish the modules to places where they can then be consumed, it's not to deploy the software directly into production, hence it is only Continuous Delivery, not Continuous Deployment. If you bolt on a piece in the build code that pushes this directly to production, then it is Continuous Deployment.
