document.addEventListener('DOMContentLoaded', () => {
    // Initialize Lucide Icons
    lucide.createIcons();

    // Navbar scroll effect
    const navbar = document.getElementById('navbar');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 20) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    });

    // Scroll Reveal Animations
    // Automatically add reveal class to key structural elements
    const elementsToReveal = document.querySelectorAll('.section-header, .content-card, .skill-card, .timeline-item, .project-card, .cert-card, .contact-card, .hero-text, .hero-image-wrapper');
    
    elementsToReveal.forEach((el, index) => {
        el.classList.add('reveal');
        
        // Add slight staggered delays to grid items so they pop up one by one
        if (el.classList.contains('skill-card') || el.classList.contains('project-card') || el.classList.contains('cert-card') || el.classList.contains('timeline-item')) {
            el.style.transitionDelay = `${(index % 3) * 0.15}s`;
        }
    });

    // Intersection Observer to trigger animations when scrolling into view
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
            }
        });
    }, {
        threshold: 0.1, // Trigger when 10% of the element is visible
        rootMargin: "0px 0px -50px 0px" // Trigger slightly before it hits the bottom
    });

    document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

    // Mobile Menu Toggle
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const navLinks = document.getElementById('navLinks');

    if (mobileMenuBtn && navLinks) {
        mobileMenuBtn.addEventListener('click', () => {
            navLinks.classList.toggle('active');
        });

        // Close menu when clicking a link
        const links = navLinks.querySelectorAll('a');
        links.forEach(link => {
            link.addEventListener('click', () => {
                navLinks.classList.remove('active');
            });
        });
    }
});
