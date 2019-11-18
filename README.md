

# PowerCD

[![PSGallery][]][PSGalleryLink]
[![PSGalleryDL][]][PSGalleryDLLink]

[![Actions][]][ActionsLink]
[![GHRelease][]][GHReleaseLink]

[![ActionsPrerelease][]][ActionsPrereleaseLink]
[![GHPreRelease][]][GHPreReleaseLink]
---

This project's goal is to deliver an opinionated continuous deployment framework that anyone can use to build powershell modules to be published on the Powershell Gallery.

This will provide a "Getting Started" process to building powershell modules, and will automate as much as possible all the dirty stuff such as building, testing, and deployment/publishing.

## Project Impetus

"The beauty of standards is that there are so many to choose from"

I wanted to create a standard methodology to build powershell modules, as the options when I was getting started making modules were bewildering and complicated, and there was no comprehensive guide or solution.

## Initial Release Goals

### Provide a development environment that supports three scenarios

1. Open Source with Visual Studio Code, GitHub, PSGallery, Appveyor
2. Private Development with Azure Devops and Azure Devops Pipelines
3. Local Build with no Internet Access
- Make the build process have all external internet-connected dependencies optional, so you can just build locally/privately if you want with nothing more than a local git repository


### Make the process build once, run anywhere for minimum following platforms
1. Windows with Powershell v5+
2. Windows with Powershell Core v6.0.1+
3. Linux with Powershell Core v6.0.1+
4. MacOS with Powershell Core v6.0.1+

### Make the build process work in userspace, not requiring admin privileges for dependencies if at all possible

### Provide a Plaster template for generating the initial module continuous deployment framework

### PowerCD builds PowerCD - The same build process for PowerCD (with some minor meta adjustments) is used for the downstream modules

### Heavy Testing - PowerCD (after building itself) deploys two plaster templates (default and custom settings), and then in turn builds and tests them

This project uses inspiration and some code from [ZLoeber's ModuleBuild](https://github.com/zloeber/ModuleBuild)

## Design Decisions

Making a template that meets everyone's needs or preferences is nearly impossible, so instead this module's focus is on "smart defaults" and "prescriptive guidance" to help new module builders get a continuous deployment pipeline. Advanced users can fork or add whatever "plugins" they want to the XML to support their personal preferences.

I've tried to select products with broad support, especially within the Powershell Github repository itself, to ensure users have a good ecosystem of support.

I've also tried tried to ensure that projects will "build" on any Windows or Linux machine with full documentation/etc. without any external dependencies, so if you choose not to use Github/Appveyor/etc. and want to use PowerCD inside an organization with no internet access, you can.

### Prescriptive Module Layout and Organization

Based on RamblingCookieMonster's template plus what is seen in the community. (Public/Private/Lib)

### Versioning

We use GitVersion to establish automatic versions and tags of the module so you don't have to keep track.

If you use Github and Appveyor, this may lead to inconsistencies between local and remote if you don't sync after every commit (e.g. your local "tag" may be 0.2.5 for the same commit on Appveyor that says 0.2.1, if you make 5 changes and build 5 times locally, but then only sync once) . This is fine if you use VSCode because it automatically overwrites the local tags with the "correct" GitHub/VSTS tags every time you sync, but you can do it using any other editor as long as your git pull command includes the --tags argument.

Semantic versioning is all meaningful version numbers, so don't worry about the specific number, just use the +semver commit messages whenever you make a feature or breaking change, and it will "figure it out". If you want to explicity set a module version, just tag the commit with the version you want (e.g. git tag v3.0.0) and push it to Github/VSTS/Whatever (git push origin v3.0.0). All future builds will start basing off that number.

### Prescriptive Services and Products

- Versioning Tool - [GitVersion](https://gitversion.readthedocs.io/en/latest/)
- Versioning Scheme - [Semantic Versioning](https://semver.org/)
- Build Tool - [Invoke-Build](https://github.com/nightroman/Invoke-Build). Only used for packaging/versioning, this plaster is primarily for script modules.
- Build Host - [Appveyor](https://www.appveyor.com/) ([Windows](https://www.appveyor.com/docs/) and [Linux](https://www.appveyor.com/docs/getting-started-with-appveyor-for-linux/))
- Commit Messages - [AngularJS Commit Message Conventions](https://github.com/angular/angular/blob/master/CONTRIBUTING.md#commit)
- Code Testing Tool - [Pester](https://github.com/pester/Pester) and [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- Code Coverage Host - [CodeCov](https://codecov.io)
- Documentation - [PlatyPS](https://github.com/PowerShell/platyPS)
- Documentation Host - [ReadTheDocs](https://docs.readthedocs.io)
- Coding Process - [Git Ship](https://markshust.com/2018/04/07/introducing-git-ship-simplified-git-flow-workflow)
    - Next release is always named release/Prerelease, and is always deployable as a prerelease build
    - Feature Branches pull request to release/Prerelease
    - release/Prerelease pull requests to master for production release
- Repository - [Git](https://git-scm.com/) (Local, [Github](https://github.com/), or [Azure Devops](https://dev.azure.com/))
- Deploy Targets
  - Local (Release Folder .zip and .nupkg)
  - Local (Install-Module via Temporary Repository)
  - [GitHub Releases](https://help.github.com/articles/about-releases/)
  - [Powershell Gallery](https://www.powershellgallery.com/)
  - [Azure Devops Packages](https://docs.microsoft.com/en-us/vsts/package/overview?view=vsts)
  - Any repository supported by Publish-Module.

## FAQs / Whatabouts

**Why do you only support PS5.1+ and PS Core as build environments?**

PS5.1 is the "last" version of Windows Powershell, as such it makes a good Long Term Support (LTS) target. The inclusion of the Powershell Gallery and its proven stability (VMware/AWS/Azure all use it as their primary delivery mechanism) allows requirements and dependencies to be managed. Also specific to modules, multi-version support became standard so the logic and testing is based around that.

You can still use PowerCD to build modules that are compatible with PSv2-4, however there is no inherent PSv2-4 specific testing in the PowerCD process and you will have to test separately. Appveyor no longer provides any images that have PSv4 on them so you'll have to do this in Jenkins or a local machine with PSv2-4 installed.

**What about Travis?**

Appveyor added Linux support in May 2018 and it works, so we use that for PowerCD builds as the default to keep it consistent. You can always add a Travis build later.

**What about OSX builds and testing?**

Will add Travis support to do this later, right now focus is just on WindowsPowershell and Powershell Core builds on Windows and Linux (ubuntu as test target). If the linux build passes, it's probably going to be OK on OSX.

**Why /Release for build output instead of /BuildOutput or /Output**

Because it has a vscode-icons default icon and the others do not. Build and Out have default vscode icons, but people may already be using those to keep files in existing projects.

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

---
[![ADO][]][ADOLink]
[![ADOTests][]][ADOTestsLink]

[![ADOPrerelease][]][ADOPrereleaseLink]
[![ADOPrereleaseTests][]][ADOPrereleaseTestsLink]

[![AppV][]][AppVLink]
[![AppVTests][]][AppVTestsLink]

[![AppPrerelease][]][AppPrereleaseLink]
[![AppPrereleaseTests][]][AppPrereleaseTestsLink]

[![Travis Status](https://api.travis-ci.org/JustinGrote/PowerCD.svg?branch=master)](https://travis-ci.org/JustinGrote/PowerCD)



[PSGallery]: https://img.shields.io/powershellgallery/v/PowerCD.svg?logo=powershell&label=Powershell+Gallery+Latest
[PSGalleryLink]: https://www.powershellgallery.com/packages/PowerCD

[PSGalleryDL]: https://img.shields.io/powershellgallery/dt/PowerCD.svg?logo=powershell&label=downloads
[PSGalleryDLLink]: https://www.powershellgallery.com/packages/PowerCD

[ADO]: https://dev.azure.com/justingrote/Default/_apis/build/status/JustinGrote.PowerCD?branchName=production&label=Current
[ADOLink]: https://dev.azure.com/justingrote/Github/_build?definitionId=1

[ADOTests]: https://img.shields.io/azure-devops/tests/justingrote/github/1/production?label=Tests&logo=azure-pipelines
[ADOTestsLink]: https://dev.azure.com/justingrote/Github/_build?definitionId=1

[ADOPrerelease]: https://dev.azure.com/justingrote/Default/_apis/build/status/JustinGrote.PowerCD?branchName=master&label=Prerelease
[ADOPrereleaseLink]: https://dev.azure.com/justingrote/Github/_build?definitionId=1&_a=summary&repositoryFilter=1&branchFilter=2

[ADOPrereleaseTests]: https://img.shields.io/azure-devops/tests/justingrote/Github/1/master?logo=azure-pipelines&label=Tests
[ADOPrereleaseTestsLink]: https://ci.appveyor.com/project/JustinGrote/powercd/build/tests

[AppV]: https://img.shields.io/appveyor/ci/justingrote/powercd/master.svg?logo=appveyor&label=Current
[AppVLink]: https://ci.appveyor.com/project/JustinGrote/PowerCD

[AppVTests]: https://img.shields.io/appveyor/tests/justingrote/powercd/master.svg?logo=appveyor&label=Tests
[AppVTestsLink]: https://ci.appveyor.com/project/JustinGrote/powercd/build/tests

[GHRelease]:https://img.shields.io/github/downloads/justingrote/PowerCD/latest/total.svg?logo=github&label=Download
[GHReleaseLink]: https://github.com/JustinGrote/PowerCD/releases/latest

[AppPrerelease]: https://img.shields.io/appveyor/ci/justingrote/powercd/production.svg?logo=appveyor&label=Prerelease
[AppPrereleaseLink]: https://ci.appveyor.com/project/JustinGrote/PowerCD

[AppPrereleaseTests]: https://img.shields.io/appveyor/tests/justingrote/powercd/release/master.svg?logo=appveyor&label=Tests
[AppPrereleaseTestsLink]: https://ci.appveyor.com/project/JustinGrote/powercd/history

[GHPreRelease]: https://img.shields.io/github/downloads-pre/justingrote/PowerCD/total.svg?logo=github&label=Download
[GHPreReleaseLink]: https://github.com/JustinGrote/PowerCD/releases

[Actions]: https://github.com/JustinGrote/PowerCD/workflows/PowerCD%20Build/badge.svg?branch=production
[ActionsLink]: https://github.com/justingrote/PowerCD/actions

[ActionsPreRelease]: https://github.com/JustinGrote/PowerCD/workflows/PowerCD%20Build/badge.svg?branch=master
[ActionsPreReleaseLink]: https://github.com/justingrote/PowerCD/actions