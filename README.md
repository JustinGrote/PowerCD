

# PowerCD

[![PSGallery][]][PSGalleryLink] [![PSGalleryDL][]][PSGalleryDLLink]

[![AppV][]][AppVLink] [![AppVTests][]][AppVTestsLink] [![GHRelease][]][GHReleaseLink]

[![AppVNext][]][AppVNextLink] [![AppVNextTests][]][AppVNextTestsLink] [![GHPreRelease][]][GHPreReleaseLink]

---

This project's goal is to deliver a continuous deployment framework that anyone can use to build powershell modules to be published on the Powershell Gallery.

This will provide a "Getting Started" process to building powershell modules, and will automate as much as possible all the dirty stuff such as building, testing, and deployment/publishing.

## Project Impetus

"The beauty of standards is that there are so many to choose from"

I wanted to create a standard methodology to build powershell modules, as the options when I was getting started making modules were bewildering and complicated, and there was no comprehensive guide or solution.

## Release Goals

### Initial Release Goals

Provide an Invoke-Build process that supports two scenarios:

1. Open Source with Visual Studio Code, GitHub, PSGallery, Appveyor
2. Local Build with no Internet Access
- Make the build process have all external internet-connected dependencies optional, so you can just build locally/privately if you want with nothing more than a local git repository

- Make the process build once, run anywhere for minimum following platofmrs
1. Windows with Powershell v5+
2. Windows with Powershell Core v6.0.1+
3. Linux with Powershell Core v6.0.1+
4. *Maybe* MacOS with Powershell Core v6.0.1+

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
  - [GitHub Releases](https://help.github.com/articles/about-releases/)
  - [Powershell Gallery](https://www.powershellgallery.com/)
  - [VSTS Package Feed](https://docs.microsoft.com/en-us/vsts/package/overview?view=vsts)
  - Any repository supported by Publish-Module.

### FAQs / Whatabouts

*Why do you only support PS5.1 and PS6 as build environments?*

PS5.1 is the "last" version of Windows Powershell, as such it makes a good Long Term Support (LTS) target. The inclusion of the Powershell Gallery and its proven stability (VMware/AWS/Azure all use it as their primary delivery mechanism) allows requirements and dependencies to be managed. Also specific to modules, multi-version support became standard so the logic and testing is based around that.

You can still use PowerCD to build modules that are compatible with PSv2-4, however there is no inherent PSv2-4 specific testing in the PowerCD process and you will have to test separately. Appveyor no longer provides any images that have PSv4 on them so you'll have to do this in Jenkins or a local machine with PSv2-4 installed.

**What about Travis?**

Appveyor added Linux support in May 2018 and it works, so we use that for PowerCD builds as the default to keep it consistent. You can always add a Travis build later.

**What about OSX builds and testing?**

Will add Travis support to do this later, right now focus is just on WindowsPowershell and Powershell Core builds on Windows and Linux (ubuntu as test target). If the linux build passes, it's probably going to be OK on OSX.

**Why not a /src directory?**

Powershell script modules by default in my opinion should usable with import-module from a direct "git checkout" of the source, even if the versioning is inaccurate (because it is dynamically determined by GitVersion at build time). Organizing things into a /src directory would defeat that purpose/goal especially since Powershell doesn't need to be "compiled" like C#, it is an interpreted language.

**What about Binary Modules?**

This template is targeted for people new to module building, so they probably aren't building .NET-based modules, maybe included a .NET library here or there in /lib. Binary Module support is on the way-later roadmap.

**Why not PSake?**

While PSake is more popular, Invoke-Build has sufficient improvements and Powershell Team support, as well as better portability.

This plaster is designed so that someone who is new to building modules doesn't have to touch the build script, they just have to place things into Private, Public, and lib, so it's less important for them to have intimate knowledge of the build script, especially since all it primarily does currently is release management and versioning automation, not actual "building/compiling" of code.

**Why CodeCov? Why not Coveralls?**

CodeCov is what the [official Powershell Core repository uses](https://codecov.io/gh/PowerShell/PowerShell), plus I think the reports look cleaner.

**What about Bitbucket/GitLab/Etc?**

Low demand and trying to keep the compatibility matrix small. You can still build a module and then upload it to one of these, and all the local build tools will still work, but it won't be tested/supported for PowerCD.

If you're concerned about Microsoft buying GitHub, well, Powershell Core is on GitHub, so I guess you'll stop using that too right?

**Why don't you call this Continuous Deployment?**

The function of this module is to publish the modules to places where they can then be consumed, it's not to deploy the software directly into production, hence it is only Continuous Delivery, not Continuous Deployment. If you bolt on a piece in the build code that pushes this directly to production, then it is Continuous Deployment.

**Why is the version tagging so weird?**
We use GitVersion to establish automatic versions and tags of the module so you don't have to keep track. If you use Github and Appveyor, this may lead to inconsistencies between local and remote if you don't sync after every commit (e.g. your local "tag" may be 0.2.5 for the same commit on Appveyor that says 0.2.1, if you make 5 changes and build 5 times locally, but then only sync once) . This is fine if you use VSCode because it automatically overwrites the local tags with the "correct" GitHub/VSTS tags every time you sync, but you can do it using any other editor as long as your git pull command includes the --tags argument.

Semantic versioning is all meaningful version numbers, so don't worry about the specific number, just use the +semver commit messages whenever you make a feature or breaking change, and it will "figure it out". If you want to explicity set a module version, just tag the commit with the version you want (e.g. git tag v3.0.0) and push it to Github/VSTS/Whatever (git push origin v3.0.0). All future builds will start basing off that number.

[PSGallery]: https://img.shields.io/powershellgallery/v/PowerCD.svg?logo=windows&label=Powershell+Gallery+Latest
[PSGalleryLink]: https://www.powershellgallery.com/packages/PowerCD

[PSGalleryDL]: https://img.shields.io/powershellgallery/dt/PowerCD.svg?logo=windows&label=downloads
[PSGalleryDLLink]: https://www.powershellgallery.com/packages/PowerCD

[AppV]: https://img.shields.io/appveyor/ci/justingrote/powercd/master.svg?logo=appveyor&label=stable
[AppVLink]: https://ci.appveyor.com/project/JustinGrote/PowerCD

[AppVTests]: https://img.shields.io/appveyor/tests/justingrote/powercd/master.svg?logo=appveyor&label=tests
[AppVTestsLink]: https://ci.appveyor.com/project/JustinGrote/powercd/build/tests

[GHRelease]:https://img.shields.io/github/downloads/justingrote/PowerCD/latest/total.svg?logo=github&label=download
[GHReleaseLink]: https://github.com/JustinGrote/PowerCD/releases/latest

[AppVNext]: https://img.shields.io/appveyor/ci/justingrote/powercd/release-vNext.svg?logo=appveyor&label=vNext
[AppVNextLink]: https://ci.appveyor.com/project/JustinGrote/PowerCD

[AppVNextTests]: https://img.shields.io/appveyor/tests/justingrote/powercd/release/vNext.svg?logo=appveyor&label=tests
[AppVNextTestsLink]: https://ci.appveyor.com/project/JustinGrote/powercd/history

[GHPreRelease]: https://img.shields.io/github/downloads-pre/justingrote/PowerCD/total.svg?logo=github&label=download
[GHPreReleaseLink]: https://github.com/JustinGrote/PowerCD/releases

